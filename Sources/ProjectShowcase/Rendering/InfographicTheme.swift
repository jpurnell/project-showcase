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

    /// The `<style>` element to place first inside an `<svg class="ig">`.
    ///
    /// Every selector is scoped under `svg.ig` and every class carries an `ig-` prefix, because an
    /// inlined chart's `<style>` is part of the page: a bare `.card` or `.label` would restyle the
    /// page's own. Colours prefer the page's token variable (`var(--label, ...)`), which follows both
    /// the OS and a manual theme toggle; the fallback is this file's own `--ig-*` value, driven by
    /// the OS through media queries, which is what an `<img>` or a file opened on its own sees.
    static var styleElement: String {
        """
          <style>
            svg.ig {
        \(lightVariables)
              font-family: \(fontStack);
            }
            svg.ig .ig-bg { fill: var(--background, var(--ig-background)); }
            svg.ig .ig-rule { fill: var(--label, var(--ig-label)); }
            svg.ig .ig-hair { stroke: var(--separator, var(--ig-separator)); stroke-width: \(Metrics.hairline); }
            svg.ig .ig-label { fill: var(--label, var(--ig-label)); }
            svg.ig .ig-muted { fill: var(--secondary-label, var(--ig-secondary-label)); }
            svg.ig .ig-bar, svg.ig .ig-dot, svg.ig .ig-s1 { fill: var(--series-1, var(--ig-series-1)); }
            svg.ig .ig-hole { fill: var(--background, var(--ig-background)); }
            svg.ig .ig-s2 { fill: var(--series-2, var(--ig-series-2)); }
            svg.ig .ig-s3 { fill: var(--series-3, var(--ig-series-3)); }
            svg.ig .ig-s4 { fill: var(--series-4, var(--ig-series-4)); }
            @media (prefers-color-scheme: dark) {
              svg.ig {
        \(darkVariables)
              }
            }
            @media (prefers-contrast: more) {
              svg.ig {
        \(contrastVariables(.light))
              }
            }
            @media (prefers-contrast: more) and (prefers-color-scheme: dark) {
              svg.ig {
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
            ("--ig-label", ColorToken.label.value(in: appearance)),
            ("--ig-secondary-label", ColorToken.secondaryLabel.value(in: appearance)),
            ("--ig-background", ColorToken.background.value(in: appearance)),
            ("--ig-secondary-background", ColorToken.secondaryBackground.value(in: appearance)),
            ("--ig-separator", ColorToken.separator.value(in: appearance))
        ]
    }

    private static func series(_ colours: [RGB]) -> [(String, RGB)] {
        colours.prefix(seriesCount).enumerated().map { ("--ig-series-\($0.offset + 1)", $0.element) }
    }

    private static func variables(_ entries: [(String, RGB)], indent: Int) -> String {
        let pad = String(repeating: " ", count: indent)
        return entries.map { "\(pad)\($0.0): \($0.1.hex);" }.joined(separator: "\n")
    }
}
