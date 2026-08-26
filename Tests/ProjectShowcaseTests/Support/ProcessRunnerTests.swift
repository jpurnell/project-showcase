//
//  ProcessRunnerTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-08-25.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("ProcessRunner Tests")
struct ProcessRunnerTests {

    @Test("Captures standard output of a successful run")
    func capturesStandardOutput() throws {
        let result = try ProcessRunner.run("/bin/echo", arguments: ["hello"])

        #expect(result.exitStatus == 0)
        #expect(result.didSucceed)
        #expect(result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines) == "hello")
        #expect(result.standardError.isEmpty)
    }

    @Test("Reports a non-zero exit status without throwing")
    func reportsNonZeroExitStatus() throws {
        let missing = "/nonexistent-\(UUID().uuidString)"
        let result = try ProcessRunner.run("/bin/ls", arguments: [missing])

        #expect((1...2).contains(result.exitStatus), "ls reports 1 on Darwin, 2 on GNU coreutils")
        #expect(result.didSucceed == false)
        #expect(result.standardError.isEmpty == false, "ls should explain itself on stderr")
    }

    @Test("Keeps standard output and standard error apart")
    func separatesStreams() throws {
        let missing = "/nonexistent-\(UUID().uuidString)"
        let result = try ProcessRunner.run("/bin/ls", arguments: [missing])

        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.contains(missing))
    }

    @Test("Drains output larger than a pipe buffer without deadlocking")
    func drainsLargeOutput() throws {
        let result = try ProcessRunner.run("/usr/bin/seq", arguments: ["1", "200000"])

        #expect(result.exitStatus == 0)
        #expect(result.standardOutput.utf8.count > 65_536, "Output should exceed a 64KB pipe buffer")
        #expect(result.standardOutput.hasSuffix("200000\n"))
    }

    @Test("Terminates a child that outlives its timeout")
    func terminatesOnTimeout() throws {
        // A 30s child under a 250ms deadline: the run can only return by the watchdog signalling
        // it, so the error below is the bound. An unbounded runner fails this test 30s later.
        var thrownError: Error?
        do {
            _ = try ProcessRunner.run("/bin/sleep", arguments: ["30"], timeout: .milliseconds(250))
        } catch {
            thrownError = error
        }

        let showcaseError = try #require(thrownError as? ShowcaseError)
        guard case .processTimedOut(let executable, let seconds) = showcaseError else {
            Issue.record("Expected .processTimedOut, got \(showcaseError)")
            return
        }
        #expect(executable == "/bin/sleep")
        #expect(abs(seconds - 0.25) < 0.001, "The deadline reported back should be the one asked for")
    }

    @Test("Runs in the requested working directory")
    func honoursWorkingDirectory() throws {
        let directory = try makeFixtureDirectory(prefix: "runner-cwd")
        let result = try ProcessRunner.run("/bin/pwd", workingDirectory: directory)

        let printed = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(printed.hasSuffix(directory.lastPathComponent))
    }

    @Test("Passes the requested environment to the child")
    func honoursEnvironment() throws {
        let result = try ProcessRunner.run(
            "/usr/bin/env",
            environment: ["SHOWCASE_FIXTURE": "present"]
        )

        #expect(result.standardOutput.contains("SHOWCASE_FIXTURE=present"))
    }

    @Test("Throws rather than trapping when the executable is missing")
    func throwsForMissingExecutable() throws {
        var thrownError: Error?
        do {
            _ = try ProcessRunner.run("/nonexistent-\(UUID().uuidString)/binary")
        } catch {
            thrownError = error
        }

        let showcaseError = try #require(thrownError as? ShowcaseError)
        guard case .extractionFailed(let source, let message) = showcaseError else {
            Issue.record("Expected .extractionFailed, got \(showcaseError)")
            return
        }
        #expect(source == "binary")
        #expect(message.contains("Could not start"))
    }

    @Test("Rejects a non-positive timeout")
    func rejectsNonPositiveTimeout() throws {
        var thrownError: Error?
        do {
            _ = try ProcessRunner.run("/bin/echo", arguments: ["hi"], timeout: .zero)
        } catch {
            thrownError = error
        }

        let showcaseError = try #require(thrownError as? ShowcaseError)
        guard case .invalidConfiguration(let message) = showcaseError else {
            Issue.record("Expected .invalidConfiguration, got \(showcaseError)")
            return
        }
        #expect(message.contains("Timeout must be positive"))
    }
}
