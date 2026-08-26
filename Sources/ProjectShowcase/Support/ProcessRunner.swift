//
//  ProcessRunner.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-08-25.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// What a finished child process left behind.
public struct ProcessResult: Sendable, Equatable {

    /// The child's exit status, or the signal number when it was killed.
    public let exitStatus: Int32

    /// Everything the child wrote to `stdout`, decoded as UTF-8.
    public let standardOutput: String

    /// Everything the child wrote to `stderr`, decoded as UTF-8.
    public let standardError: String

    /// Whether the child exited cleanly.
    public var didSucceed: Bool { exitStatus == 0 }

    /// Creates a result.
    ///
    /// - Parameters:
    ///   - exitStatus: The child's exit status.
    ///   - standardOutput: The child's `stdout`.
    ///   - standardError: The child's `stderr`.
    public init(exitStatus: Int32, standardOutput: String, standardError: String) {
        self.exitStatus = exitStatus
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// The one place in this package that spawns a subprocess.
///
/// Every subprocess in ProjectShowcase runs through ``run(_:arguments:workingDirectory:environment:timeout:)``,
/// so the two ways a spawn hangs have exactly one place to go wrong rather than one per call site:
///
/// - **The wait.** `waitUntilExit()` returns when the child exits or never. It cannot be bounded
///   in place, so it is bounded from outside by a watchdog that signals the child at the deadline.
/// - **The read.** A `Pipe` holds roughly 64KB. A child that writes more blocks until someone
///   drains it, and a parent that waits for exit before draining deadlocks against it. The child's
///   streams are therefore redirected to files, which never fill and never block, and are read
///   after the child is gone.
///
/// No shell is involved: the executable and each argument are passed as separate `argv` entries,
/// so nothing in an argument is parsed as a command.
public enum ProcessRunner {

    /// How long a child may run before the watchdog signals it.
    public static let defaultTimeout: Duration = .seconds(60)

    /// How long a signalled child has to exit on `SIGTERM` before it is killed outright.
    private static let gracePeriod: Duration = .seconds(2)

    /// Runs `executablePath` to completion, bounded by `timeout`.
    ///
    /// A non-zero exit status is a result, not an error — the caller decides whether it matters.
    /// Only a child that fails to start, or one that outlives its timeout, throws.
    ///
    /// - Parameters:
    ///   - executablePath: Absolute path to the program to run.
    ///   - arguments: Arguments passed as individual `argv` entries, never parsed by a shell.
    ///   - workingDirectory: Directory to run in. Standardized before use.
    ///   - environment: The child's full environment, or `nil` to inherit this process's.
    ///   - timeout: How long the child may run. Must be positive.
    /// - Returns: The child's exit status and captured output.
    /// - Throws: ``ShowcaseError/invalidConfiguration(message:)`` for a non-positive timeout,
    ///   ``ShowcaseError/processTimedOut(executable:seconds:)`` when the deadline is reached, and
    ///   ``ShowcaseError/extractionFailed(source:message:)`` when the child cannot be started.
    public static func run(
        _ executablePath: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: Duration = defaultTimeout
    ) throws -> ProcessResult {
        let timeoutSeconds = seconds(timeout)
        guard timeoutSeconds > 0 else {
            throw ShowcaseError.invalidConfiguration(
                message: "Timeout must be positive, got \(timeoutSeconds)s for \(executablePath)"
            )
        }

        let capture = try StreamCapture()
        defer { capture.discard() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = workingDirectory?.standardizedFileURL
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = capture.standardOutputHandle
        process.standardError = capture.standardErrorHandle

        do {
            try process.run()
        } catch {
            throw ShowcaseError.extractionFailed(
                source: (executablePath as NSString).lastPathComponent,
                message: "Could not start \(executablePath): \(error.localizedDescription)"
            )
        }

        let watchdog = TimeoutWatchdog(
            pid: process.processIdentifier,
            after: timeoutSeconds,
            gracePeriod: seconds(gracePeriod)
        )
        process.waitUntilExit()
        let didTimeOut = watchdog.disarm()

        let captured = try capture.readAndClose()

        guard !didTimeOut else {
            throw ShowcaseError.processTimedOut(
                executable: executablePath,
                seconds: timeoutSeconds
            )
        }

        return ProcessResult(
            exitStatus: process.terminationStatus,
            standardOutput: captured.standardOutput,
            standardError: captured.standardError
        )
    }

    /// Converts a `Duration` to seconds without dividing by a value that could be zero.
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) * 1e-18
    }
}

// MARK: - Stream capture

/// The child's `stdout` and `stderr`, backed by files rather than pipes.
///
/// A file never fills, so the child never blocks on a full buffer and the parent never has to
/// interleave draining with waiting. Both files live in the temporary directory under a UUID name
/// and are removed when the run ends.
private struct StreamCapture {
    private let standardOutputURL: URL
    private let standardErrorURL: URL
    let standardOutputHandle: FileHandle
    let standardErrorHandle: FileHandle

    init() throws {
        standardOutputURL = Self.scratchURL(suffix: "stdout")
        standardErrorURL = Self.scratchURL(suffix: "stderr")
        try Data().write(to: standardOutputURL)
        try Data().write(to: standardErrorURL)
        standardOutputHandle = try FileHandle(forWritingTo: standardOutputURL)
        standardErrorHandle = try FileHandle(forWritingTo: standardErrorURL)
    }

    private static func scratchURL(suffix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("showcase-\(suffix)-\(UUID().uuidString)")
            .standardizedFileURL
    }

    /// Closes the write ends and reads back what the child wrote.
    ///
    /// Decoding is lossy by construction: a child is free to emit bytes that are not UTF-8, and
    /// losing a byte of diagnostic output is preferable to failing a run over it. A file that
    /// cannot be read at all is a different matter and propagates — both files were created here,
    /// so an unreadable one means something outside this type went wrong.
    func readAndClose() throws -> (standardOutput: String, standardError: String) {
        try? standardOutputHandle.close() // silent: the write end is already gone with the child
        try? standardErrorHandle.close() // silent: the write end is already gone with the child
        return (try Self.contents(of: standardOutputURL), try Self.contents(of: standardErrorURL))
    }

    private static func contents(of url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    /// Removes both scratch files, closing the handles first if the caller never read them.
    func discard() {
        try? standardOutputHandle.close() // silent: closing twice is not an error worth raising
        try? standardErrorHandle.close() // silent: closing twice is not an error worth raising
        try? FileManager.default.removeItem(at: standardOutputURL) // silent: scratch file
        try? FileManager.default.removeItem(at: standardErrorURL) // silent: scratch file
    }
}

// MARK: - Watchdog

/// Signals a child that outlives its deadline, then reports whether it had to.
///
/// Signals go to the pid rather than to the `Process`, because `Process` is not `Sendable` and the
/// deadline fires on another queue. The residual race is one instruction wide — between
/// `waitUntilExit()` reaping the child and ``disarm()`` being called, an escalation already past
/// its guard could signal a reused pid — and closing it entirely would mean holding a lock across
/// the wait, which is the hang this class exists to prevent.
// Justification: mutable state is guarded by `lock`; the watchdog fires on a background queue.
private final class TimeoutWatchdog: @unchecked Sendable {
    private let lock = NSLock()
    private let pid: pid_t
    private var didFire = false
    private var isDisarmed = false

    /// Arms the watchdog for a child that is already running.
    ///
    /// - Parameters:
    ///   - pid: The child's process identifier.
    ///   - timeout: Seconds before `SIGTERM`.
    ///   - gracePeriod: Seconds between `SIGTERM` and `SIGKILL`.
    init(pid: pid_t, after timeout: Double, gracePeriod: Double) {
        self.pid = pid
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.fire(gracePeriod: gracePeriod)
        }
    }

    /// Stops the watchdog and reports whether the deadline had already passed.
    func disarm() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        isDisarmed = true
        return didFire
    }

    private func fire(gracePeriod: Double) {
        lock.lock()
        guard !isDisarmed else {
            lock.unlock()
            return
        }
        didFire = true
        lock.unlock()

        kill(pid, SIGTERM)
        DispatchQueue.global().asyncAfter(deadline: .now() + gracePeriod) { [weak self] in
            self?.escalate()
        }
    }

    private func escalate() {
        lock.lock()
        let stillRunning = !isDisarmed
        lock.unlock()
        guard stillRunning else { return }
        kill(pid, SIGKILL)
    }
}
