//
//  TestOutputParserTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("TestOutputParser Tests")
struct TestOutputParserTests {

    // MARK: - Swift Testing Framework Output

    @Test("Parses Swift Testing passing output — test count")
    func swiftTestingTestCount() throws {
        let output = """
        Build complete! (3.21s)
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 58)
    }

    @Test("Parses Swift Testing passing output — suite count")
    func swiftTestingSuiteCount() throws {
        let output = """
        Build complete! (3.21s)
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.suiteCount == 11)
    }

    @Test("Parses Swift Testing passing output — pass rate is 1.0")
    func swiftTestingPassRate() throws {
        let output = """
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        let rate = try #require(facts.passRate)
        #expect(abs(rate - 1.0) < 1e-6)
    }

    // MARK: - XCTest Output

    @Test("Parses XCTest passing output — test count")
    func xcTestTestCount() throws {
        let output = """
        Test Suite 'All tests' started at 2026-05-11 16:49:32.279.
        Test Suite 'All tests' passed at 2026-05-11 16:49:32.280.
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 53)
    }

    @Test("Parses XCTest passing output — pass rate is 1.0 when 0 failures")
    func xcTestPassRate() throws {
        let output = """
        Test Suite 'All tests' passed at 2026-05-11 16:49:32.280.
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        let rate = try #require(facts.passRate)
        #expect(abs(rate - 1.0) < 1e-6)
    }

    @Test("XCTest-only output reports suite count of 0")
    func xcTestSuiteCountDefaultsToZero() throws {
        let output = """
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.suiteCount == 0)
    }

    // MARK: - Mixed Output (Swift Testing + XCTest)

    @Test("Mixed output sums test counts from both frameworks")
    func mixedOutputSumsTestCounts() throws {
        let output = """
        Build complete! (5.42s)
        Test Suite 'All tests' started at 2026-05-11 16:49:32.279.
        Test Suite 'All tests' passed at 2026-05-11 16:49:32.280.
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 111)
    }

    @Test("Mixed output uses Swift Testing suite count")
    func mixedOutputUsesSuiteCount() throws {
        let output = """
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.suiteCount == 11)
    }

    @Test("Mixed output with all passing has pass rate 1.0")
    func mixedOutputPassRate() throws {
        let output = """
        Executed 53 tests, with 0 failures (0 unexpected) in 0.000 (0.001) seconds
        Test run with 58 tests in 11 suites passed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        let rate = try #require(facts.passRate)
        #expect(abs(rate - 1.0) < 1e-6)
    }

    // MARK: - Failure Handling

    @Test("Swift Testing failed run calculates pass rate below 1.0")
    func swiftTestingFailedRun() throws {
        let output = """
        Test run with 58 tests in 11 suites failed after 0.512 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 58)
        #expect(facts.suiteCount == 11)
        // Swift Testing "failed" line doesn't tell us how many failed,
        // but we know passRate < 1.0
        let rate = try #require(facts.passRate)
        #expect(rate < 1.0)
    }

    @Test("XCTest failures produce correct pass rate")
    func xcTestFailures() throws {
        let output = """
        Executed 53 tests, with 3 failures (2 unexpected) in 1.234 (1.500) seconds
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 53)
        // passRate = (53 - 3) / 53 ≈ 0.9434
        let rate = try #require(facts.passRate)
        #expect(rate > 0.94)
        #expect(rate < 0.95)
    }

    @Test("Mixed output with XCTest failures and Swift Testing pass")
    func mixedOutputWithXCTestFailures() throws {
        let output = """
        Executed 50 tests, with 5 failures (3 unexpected) in 1.000 (1.200) seconds
        Test run with 100 tests in 20 suites passed after 2.000 seconds.
        """
        let parser = TestOutputParser()
        let facts = try #require(parser.parse(output: output))

        #expect(facts.testCount == 150)
        #expect(facts.suiteCount == 20)
        // 5 failures out of 150 total → passRate = 145/150 ≈ 0.9667
        let rate = try #require(facts.passRate)
        #expect(rate > 0.96)
        #expect(rate < 0.97)
    }

    // MARK: - Non-test Output

    @Test("Returns nil for output with no test results")
    func returnsNilForNonTestOutput() {
        let output = """
        Build complete! (2.15s)
        warning: some random warning
        """
        let parser = TestOutputParser()
        let facts = parser.parse(output: output)

        #expect(facts == nil)
    }

    @Test("Returns nil for empty string")
    func returnsNilForEmptyString() {
        let parser = TestOutputParser()
        let facts = parser.parse(output: "")

        #expect(facts == nil)
    }

    @Test("Returns nil for build-only output with no test summary")
    func returnsNilForBuildOnlyOutput() {
        let output = """
        Compiling MyLib main.swift
        Compiling MyLib utils.swift
        Linking MyLib
        Build complete! (1.23s)
        """
        let parser = TestOutputParser()
        let facts = parser.parse(output: output)

        #expect(facts == nil)
    }
}
