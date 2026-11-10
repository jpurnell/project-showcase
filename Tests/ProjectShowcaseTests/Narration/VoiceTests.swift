//
//  VoiceTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("Narrative voice for the owner's own site")
struct VoiceTests {

    /// Phrases that praise the work or its author. The owner's pages state what was built and decided.
    static let praise = ["show craft", "judgment and craft", "signals of craft", "Craft Signals", "compelling"]

    @Test("selfReflection pages are written in the first person")
    func firstPerson() throws {
        let prompt = try PromptBuilder().buildSystemPrompt(audience: .selfReflection, style: .caseStudy)

        #expect(prompt.contains("first person"))
        #expect(!prompt.contains("third person"))
    }

    @Test("selfReflection prompts forbid praising the work or its author")
    func noPraise() throws {
        let prompt = try PromptBuilder().buildSystemPrompt(audience: .selfReflection, style: .caseStudy)

        #expect(prompt.contains("Do not praise"))
        for phrase in Self.praise { #expect(!prompt.contains(phrase), "still asks for \(phrase)") }
    }

    @Test("The case-study structure asks for decisions and reasons, not craft")
    func structure() throws {
        let prompt = try PromptBuilder().buildSystemPrompt(audience: .selfReflection, style: .caseStudy)

        #expect(prompt.contains("Decisions"))
        #expect(prompt.contains("Motivation"))
    }

    @Test("Other audiences keep the third person")
    func othersUnchanged() throws {
        let prompt = try PromptBuilder().buildSystemPrompt(audience: .hiringManager, style: .caseStudy)

        #expect(prompt.contains("third person"))
    }

    @Test("The portfolio overview follows the same voice for selfReflection")
    func portfolioVoice() throws {
        let own = try PortfolioPromptBuilder().buildSystemPrompt(audience: .selfReflection)
        let other = try PortfolioPromptBuilder().buildSystemPrompt(audience: .hiringManager)

        #expect(own.contains("first person") && !own.contains("third person"))
        #expect(own.contains("Do not praise"))
        for phrase in Self.praise { #expect(!own.contains(phrase), "portfolio still asks for \(phrase)") }
        #expect(other.contains("third person"))
    }
}
