//
//  SettledTests.swift
//  ProjectShowcaseTests
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
@testable import ProjectShowcase

@Suite("Settled pages")
struct SettledTests {

    @Test("A page marked settled: true is settled")
    func settledPage() {
        #expect(Settlement.isSettled(existingPage: "---\ntitle: X\nsettled: true\n---\n\nbody"))
        #expect(Settlement.isSettled(existingPage: "---\nsettled: TRUE\n---\n"))
    }

    @Test("Everything else is open to regeneration")
    func openPages() {
        #expect(!Settlement.isSettled(existingPage: nil))
        #expect(!Settlement.isSettled(existingPage: "---\ntitle: X\n---\n"))
        #expect(!Settlement.isSettled(existingPage: "---\nsettled: false\n---\n"))
        #expect(!Settlement.isSettled(existingPage: "---\nsettled: maybe\n---\n"))
    }

    @Test("A settled flag in the body is ignored")
    func bodyFlagIgnored() {
        #expect(!Settlement.isSettled(existingPage: "---\ntitle: X\n---\n\nsettled: true\n"))
    }
}
