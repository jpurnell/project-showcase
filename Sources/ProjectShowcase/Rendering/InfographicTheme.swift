//
//  InfographicTheme.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import DesignTokens

/// The design system's colours and type, as a stylesheet an SVG carries with it.
///
/// An SVG loaded through `<img>` cannot read the page's CSS variables, so each chart embeds its
/// own `<style>`. Every value is taken from ``DesignTokens`` (none is typed here), and the
/// blocks follow the order `tokens.css` uses: light, OS dark, increased contrast, then
/// increased contrast in dark, each overriding only what the one before it set.
enum InfographicTheme {

    /// Series colours a chart may use, as `--series-1` ... `--series-4`.
    private static let seriesCount = 4

    /// The `<style>` element to place first inside an `<svg>`.
    static var styleElement: String {
        """
          <style>
            svg {
        \(lightVariables)
              font-family: \(fontStack);
            }
            .bg { fill: var(--background); }
            .card { fill: var(--secondary-background); }
            .frame { fill: none; stroke: var(--separator); stroke-width: \(Metrics.hairline); }
            .rule { fill: var(--label); }
            .hair { stroke: var(--separator); stroke-width: \(Metrics.hairline); }
            .label { fill: var(--label); }
            .muted { fill: var(--secondary-label); }
            .bar { fill: var(--series-1); }
            .dot { fill: var(--series-1); }
            .hole { fill: var(--background); }
            .s1 { fill: var(--series-1); }
            .s2 { fill: var(--series-2); }
            .s3 { fill: var(--series-3); }
            .s4 { fill: var(--series-4); }
            @media (prefers-color-scheme: dark) {
              svg {
        \(darkVariables)
              }
            }
            @media (prefers-contrast: more) {
              svg {
        \(contrastVariables(.light))
              }
            }
            @media (prefers-contrast: more) and (prefers-color-scheme: dark) {
              svg {
        \(contrastVariables(.dark))
              }
            }
          </style>
        """
    }

    /// Hairline weight, from the design system's `--rule-hairline`.
    private enum Metrics {
        static let hairline = 1
    }

    private static var fontStack: String {
        "-apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro', 'Helvetica Neue', Helvetica, Arial, sans-serif"
    }

    private static var lightVariables: String {
        variables(base(.light) + series(Palette.series), indent: 6)
    }

    private static var darkVariables: String {
        variables(base(.dark) + series(Palette.seriesDark), indent: 8)
    }

    private static func contrastVariables(_ appearance: Appearance) -> String {
        let palette = appearance == .light ? Palette.seriesIncreasedContrast : Palette.seriesIncreasedContrastDark
        return variables(series(palette), indent: 8)
    }

    private static func base(_ appearance: Appearance) -> [(String, RGB)] {
        [
            ("--label", ColorToken.label.value(in: appearance)),
            ("--secondary-label", ColorToken.secondaryLabel.value(in: appearance)),
            ("--background", ColorToken.background.value(in: appearance)),
            ("--secondary-background", ColorToken.secondaryBackground.value(in: appearance)),
            ("--separator", ColorToken.separator.value(in: appearance))
        ]
    }

    private static func series(_ colours: [RGB]) -> [(String, RGB)] {
        colours.prefix(seriesCount).enumerated().map { ("--series-\($0.offset + 1)", $0.element) }
    }

    private static func variables(_ entries: [(String, RGB)], indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        return entries.map { "\(pad)\($0.0): \($0.1.hex);" }.joined(separator: "\n")
    }
}
