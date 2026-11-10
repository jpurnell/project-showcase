//
//  InfographicThemeTests.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Testing
import Foundation
import DesignTokens
@testable import ProjectShowcase

@Suite("Infographic design-token theme")
struct InfographicThemeTests {

    static let card = InfographicTests.sampleCard
    static let generators: [any InfographicGenerator] = [
        StatsCardGenerator(), CommitTimelineGenerator(), ReleaseTimelineGenerator()
    ]

    /// The palette these charts were drawn in before the design system: every one of these
    /// must be gone, whichever generator wrote the SVG.
    static let legacyHex = [
        "#1a1a2e", "#16213e", "#0f3460", "#00d4ff", "#8892b0", "#e0e0e0",
        "#50fa7b", "#ff79c6", "#ffb86c"
    ]

    @Test("No generator emits a pre-design-system colour")
    func noLegacyColours() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card).lowercased()
            for hex in Self.legacyHex {
                #expect(!svg.contains(hex), "\(type(of: generator)) still emits \(hex)")
            }
        }
    }

    @Test("Colours are theme classes, not literals on the shapes")
    func shapesCarryNoLiteralColour() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card)
            let body = svg.components(separatedBy: "</style>").last ?? ""
            #expect(!body.contains("fill=\"#"), "\(type(of: generator)) paints a shape with a literal")
            #expect(!body.contains("stroke=\"#"), "\(type(of: generator)) strokes a shape with a literal")
        }
    }

    @Test("Light values come from the tokens")
    func lightValuesFromTokens() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card)
            #expect(svg.contains(ColorToken.background.light.hex))
            #expect(svg.contains(ColorToken.label.light.hex))
            #expect(svg.contains(ColorToken.separator.light.hex))
            #expect(svg.contains(Palette.series[0].hex))
        }
    }

    @Test("Dark and increased-contrast values are present, in cascade order")
    func darkAndContrastBlocks() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card)
            let dark = try #require(svg.range(of: "@media (prefers-color-scheme: dark)"))
            let contrast = try #require(svg.range(of: "@media (prefers-contrast: more)"))
            let contrastDark = try #require(
                svg.range(of: "@media (prefers-contrast: more) and (prefers-color-scheme: dark)"))
            #expect(svg.contains(ColorToken.background.value(in: .dark).hex))
            #expect(svg.contains(Palette.seriesDark[0].hex))
            #expect(svg.contains(Palette.seriesIncreasedContrast[0].hex))
            #expect(svg.contains(Palette.seriesIncreasedContrastDark[0].hex))
            // Later blocks win at equal specificity, so each override must follow what it overrides.
            #expect(dark.lowerBound < contrast.lowerBound)
            #expect(contrast.lowerBound < contrastDark.lowerBound)
        }
    }

    @Test("Swiss shape: square container, no rounded corners")
    func squareContainer() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card)
            #expect(!svg.contains("rx="), "\(type(of: generator)) rounds a corner")
        }
    }

    @Test("Each stat uses its own series colour in order")
    func statSeriesOrder() throws {
        let svg = try StatsCardGenerator().generate(from: Self.card)
        for index in 0..<4 {
            #expect(svg.contains("--series-\(index + 1): \(Palette.series[index].hex)"))
        }
    }

    @Test("Fonts are the design system's stack")
    func fontStack() throws {
        for generator in Self.generators {
            let svg = try generator.generate(from: Self.card)
            #expect(!svg.contains("font-family=\"sans-serif\""))
            #expect(svg.contains("SF Pro"))
        }
    }

    @Test("Output stays well-formed XML")
    func wellFormed() throws {
        for generator in Self.generators {
            for card in [Self.card, InfographicTests.minimalCard, InfographicTests.singleMonthCard] {
                let svg = try generator.generate(from: card)
                let parser = XMLParser(data: Data(svg.utf8))
                #expect(parser.parse(), "\(type(of: generator)): \(parser.parserError?.localizedDescription ?? "")")
            }
        }
    }
}
