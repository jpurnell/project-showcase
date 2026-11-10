//
//  OwnerPronounsTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("OwnerPronouns")
struct OwnerPronounsTests {

    private func cv(_ json: String?) throws -> URL {
        let dir = try makeFixtureDirectory(prefix: "showcase-cv")
        let url = dir.appendingPathComponent("cv.json")
        if let json { try json.write(to: url, atomically: true, encoding: .utf8) }
        return url
    }

    static let he = OwnerPronouns(subject: "he", object: "him", possessive: "his")

    // MARK: - Loading from cv.json

    @Test("Reads basics.pronouns from a cv.json")
    func loadsFromCV() throws {
        let url = try cv("""
        {"basics":{"firstName":"A","pronouns":{"subject":"he","object":"him","possessive":"his"}},"work":[]}
        """)

        #expect(try OwnerPronouns.load(fromCV: url) == Self.he)
    }

    @Test("A cv.json with no pronouns, or no file at all, gives none")
    func absentGivesNil() throws {
        #expect(try OwnerPronouns.load(fromCV: cv(#"{"basics":{"firstName":"A"}}"#)) == nil)
        #expect(try OwnerPronouns.load(fromCV: cv(nil)) == nil)
    }

    @Test("A cv.json that is not JSON is an error, not silently no pronouns")
    func malformedThrows() throws {
        let url = try cv("{ not json")
        #expect(throws: (any Error).self) { try OwnerPronouns.load(fromCV: url) }
    }

    @Test("The default cv.json sits in Resources beside the manifest")
    func defaultLocation() {
        let manifest = URL(fileURLWithPath: "/site/showcase-manifest.json")
        #expect(OwnerPronouns.defaultCVURL(besideManifest: manifest).path == "/site/Resources/cv.json")
    }

    // MARK: - The rule given to the writer

    @Test("With pronouns, the prompt names all three forms and forbids others")
    func ruleWithPronouns() {
        let rule = OwnerPronouns.rule(for: Self.he)

        #expect(rule.contains("he/him/his"))
        #expect(rule.contains("\"he\"") && rule.contains("\"him\"") && rule.contains("\"his\""))
        #expect(rule.lowercased().contains("never guess"))
    }

    @Test("Without pronouns, the prompt says not to guess and offers they or no pronoun")
    func ruleWithoutPronouns() {
        let rule = OwnerPronouns.rule(for: nil)

        #expect(rule.lowercased().contains("do not guess"))
        #expect(rule.contains("they"))
        #expect(!rule.contains("he/him"))
    }

    // MARK: - Both prompt builders carry it

    @Test("The project prompt carries the pronouns")
    func projectPrompt() throws {
        let with = try PromptBuilder().buildSystemPrompt(audience: .selfReflection, style: .caseStudy, ownerPronouns: Self.he)
        let without = try PromptBuilder().buildSystemPrompt(audience: .selfReflection, style: .caseStudy)

        #expect(with.contains("he/him/his"))
        #expect(!without.contains("he/him/his"))
        #expect(without.lowercased().contains("do not guess"))
    }

    @Test("The portfolio prompt carries the pronouns")
    func portfolioPrompt() throws {
        let with = try PortfolioPromptBuilder().buildSystemPrompt(audience: .selfReflection, ownerPronouns: Self.he)
        let without = try PortfolioPromptBuilder().buildSystemPrompt(audience: .selfReflection)

        #expect(with.contains("he/him/his"))
        #expect(without.lowercased().contains("do not guess"))
    }

    @Test("The generator hands its pronouns to the prompt it sends")
    func generatorSystemPrompt() throws {
        let generator = NarrativeGenerator(apiKey: "k", ownerPronouns: Self.he)

        #expect(try generator.systemPrompt(audience: .selfReflection, style: .caseStudy).contains("he/him/his"))
        #expect(try generator.portfolioSystemPrompt(audience: .selfReflection).contains("he/him/his"))
    }
}
