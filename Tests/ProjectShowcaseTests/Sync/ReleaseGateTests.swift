//
//  ReleaseGateTests.swift
//  ProjectShowcaseTests
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
@testable import ProjectShowcase

@Suite("Release gate")
struct ReleaseGateTests {

    @Test("The newest version is the highest, not the last listed")
    func latestVersion() {
        #expect(ReleaseGate.latestVersion(in: ["v1.2.0", "3.0.1", "2.9.9"]) == "3.0.1")
        #expect(ReleaseGate.latestVersion(in: ["1.10.0", "1.9.0"]) == "1.10.0")
        #expect(ReleaseGate.latestVersion(in: []) == nil)
    }

    @Test("A minor or major bump warrants regeneration")
    func bumps() {
        #expect(ReleaseGate.warrantsRegeneration(recorded: "3.5.1", latest: "3.6.0"))
        #expect(ReleaseGate.warrantsRegeneration(recorded: "v1.9.4", latest: "2.0.0"))
    }

    @Test("A patch release, or none at all, does not")
    func noBump() {
        #expect(!ReleaseGate.warrantsRegeneration(recorded: "3.5.0", latest: "3.5.1"))
        #expect(!ReleaseGate.warrantsRegeneration(recorded: "3.5.1", latest: "3.5.1"))
        #expect(!ReleaseGate.warrantsRegeneration(recorded: "3.5.1", latest: nil))
    }

    @Test("With no recorded version there is nothing to compare, so the page is regenerated")
    func unrecorded() {
        #expect(ReleaseGate.warrantsRegeneration(recorded: nil, latest: "1.0.0"))
        #expect(ReleaseGate.warrantsRegeneration(recorded: nil, latest: nil))
    }

    @Test("A project that has never tagged a release is regenerated when it first does")
    func firstRelease() {
        #expect(ReleaseGate.warrantsRegeneration(recorded: "", latest: "0.1.0"))
        #expect(!ReleaseGate.warrantsRegeneration(recorded: "", latest: nil))
    }
}
