//
//  EnumTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Testing
import Foundation
@testable import ProjectShowcase

@Suite("Configuration Enum Tests")
struct EnumTests {

    @Test("Audience raw values are stable for serialization")
    func audienceRawValues() {
        #expect(Audience.hiringManager.rawValue == "hiringManager")
        #expect(Audience.openSourceContributor.rawValue == "openSourceContributor")
        #expect(Audience.client.rawValue == "client")
        #expect(Audience.selfReflection.rawValue == "selfReflection")
    }

    @Test("NarrativeStyle raw values are stable")
    func narrativeStyleRawValues() {
        #expect(NarrativeStyle.caseStudy.rawValue == "caseStudy")
        #expect(NarrativeStyle.projectCard.rawValue == "projectCard")
        #expect(NarrativeStyle.deepDive.rawValue == "deepDive")
    }

    @Test("OutputFormat raw values are stable")
    func outputFormatRawValues() {
        #expect(OutputFormat.markdown.rawValue == "markdown")
        #expect(OutputFormat.html.rawValue == "html")
        #expect(OutputFormat.json.rawValue == "json")
    }

    @Test("ProjectLanguage covers expected languages")
    func projectLanguageValues() {
        #expect(ProjectLanguage.swift.rawValue == "swift")
        #expect(ProjectLanguage.typescript.rawValue == "typescript")
        #expect(ProjectLanguage.python.rawValue == "python")
        #expect(ProjectLanguage.rust.rawValue == "rust")
        #expect(ProjectLanguage.unknown.rawValue == "unknown")
    }

    @Test("All enums are Codable round-trip safe")
    func enumCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for audience in [Audience.hiringManager, .openSourceContributor, .client, .selfReflection] {
            let data = try encoder.encode(audience)
            let decoded = try decoder.decode(Audience.self, from: data)
            #expect(decoded == audience)
        }

        for style in [NarrativeStyle.caseStudy, .projectCard, .deepDive] {
            let data = try encoder.encode(style)
            let decoded = try decoder.decode(NarrativeStyle.self, from: data)
            #expect(decoded == style)
        }
    }
}
