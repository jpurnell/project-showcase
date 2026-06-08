//
//  TestOutputParser.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Parses `swift test` console output to extract test facts from
/// Swift Testing and XCTest summary lines.
public struct TestOutputParser: Sendable {

    /// Creates a new TestOutputParser instance.
    public init() {}

    /// Parse the given test output and return aggregated test facts.
    ///
    /// Recognizes two formats:
    /// - **Swift Testing**: `"Test run with N tests in M suites passed|failed after …"`
    /// - **XCTest**: `"Executed N tests, with F failures (U unexpected) in …"`
    ///
    /// When both formats appear, test counts are summed and the suite count
    /// comes from Swift Testing. Pass rate accounts for XCTest failures and
    /// Swift Testing's pass/fail status.
    ///
    /// - Parameter output: Raw console output from `swift test`.
    /// - Returns: Aggregated ``TestFacts``, or `nil` if no test summary is found.
    public func parse(output: String) -> TestFacts? {
        let swiftTesting = parseSwiftTesting(output)
        let xcTest = parseXCTest(output)

        guard swiftTesting != nil || xcTest != nil else {
            return nil
        }

        let stTestCount = swiftTesting?.testCount ?? 0
        let stSuiteCount = swiftTesting?.suiteCount ?? 0
        let xcTestCount = xcTest?.testCount ?? 0
        let xcFailures = xcTest?.failures ?? 0

        let totalTests = stTestCount + xcTestCount
        let totalSuites = stSuiteCount

        guard totalTests > 0 else { return nil }

        let passRate: Double?
        let swiftTestingFailed = swiftTesting?.failed ?? false

        if xcFailures == 0, !swiftTestingFailed {
            passRate = 1.0
        } else if swiftTestingFailed, xcTest == nil {
            // Swift Testing reported "failed" but doesn't tell us how many failed.
            // We know it's less than 1.0; use 0.0 as a sentinel.
            passRate = 0.0
        } else {
            // We have XCTest failures, possibly combined with Swift Testing.
            // Swift Testing "passed" contributes zero additional failures.
            let totalFailures = xcFailures
            let passingTests = Double(totalTests - totalFailures)
            passRate = passingTests / Double(totalTests)
        }

        return TestFacts(
            testCount: totalTests,
            suiteCount: totalSuites,
            passRate: passRate
        )
    }

    // MARK: - Private Helpers

    private struct SwiftTestingResult {
        let testCount: Int
        let suiteCount: Int
        let failed: Bool
    }

    private struct XCTestResult {
        let testCount: Int
        let failures: Int
    }

    private func parseSwiftTesting(_ output: String) -> SwiftTestingResult? {
        // Pattern: "Test run with 58 tests in 11 suites passed after 0.512 seconds."
        guard let regex = try? NSRegularExpression( // silent: pattern is a compile-time literal
            pattern: #"Test run with (\d+) tests? in (\d+) suites? (passed|failed) after"#,
            options: []
        ) else { return nil }

        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, options: [], range: range) else {
            return nil
        }

        guard let testCountRange = Range(match.range(at: 1), in: output),
              let suiteCountRange = Range(match.range(at: 2), in: output),
              let statusRange = Range(match.range(at: 3), in: output),
              let testCount = Int(output[testCountRange]),
              let suiteCount = Int(output[suiteCountRange])
        else { return nil }

        let status = String(output[statusRange])

        return SwiftTestingResult(
            testCount: testCount,
            suiteCount: suiteCount,
            failed: status == "failed"
        )
    }

    private func parseXCTest(_ output: String) -> XCTestResult? {
        // Pattern: "Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds"
        guard let regex = try? NSRegularExpression( // silent: pattern is a compile-time literal
            pattern: #"Executed (\d+) tests?, with (\d+) failures?"#,
            options: []
        ) else { return nil }

        let range = NSRange(output.startIndex..., in: output)
        guard let match = regex.firstMatch(in: output, options: [], range: range) else {
            return nil
        }

        guard let testCountRange = Range(match.range(at: 1), in: output),
              let failureCountRange = Range(match.range(at: 2), in: output),
              let testCount = Int(output[testCountRange]),
              let failures = Int(output[failureCountRange])
        else { return nil }

        return XCTestResult(testCount: testCount, failures: failures)
    }
}
