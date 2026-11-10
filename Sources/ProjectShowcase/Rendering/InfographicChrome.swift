//
//  InfographicChrome.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Foundation

/// What every chart has in common: one width, one margin, and a title above a heavy rule.
///
/// Sharing it is what keeps the three charts reading as a set. The title's size and position are
/// fixed here, not chosen by each generator, and there is no border: the rule under the title is the
/// only heavy line.
enum InfographicChrome {

    /// Width of every chart.
    static let width = 600
    /// Space between the edge and the content.
    static let margin = 24
    /// Width of the content between the margins.
    static var contentWidth: Int { width - 2 * margin }
    /// The content's left edge.
    static var left: Double { Double(margin) }
    /// The content's right edge.
    static var right: Double { Double(width - margin) }
    /// Where content may begin, just under the rule.
    static let contentTop = 64

    private static let titleBaseline = 32
    private static let titleSize = 18
    private static let ruleTop = 44
    private static let ruleHeight = 3

    /// Everything from `<svg>` through the rule under the title.
    ///
    /// - Parameters:
    ///   - height: The chart's height.
    ///   - label: The accessible name.
    ///   - title: The title, drawn at the left.
    ///   - note: A short line on the title's row, at the right.
    static func opening(height: Int, label: String, title: String, note: String? = nil) -> String {
        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" class="ig" role="img" aria-label="\(escape(label))" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
        \(InfographicTheme.styleElement)
          <rect class="ig-bg" x="0" y="0" width="\(width)" height="\(height)"/>
          <text class="ig-label" x="\(margin)" y="\(titleBaseline)" font-size="\(titleSize)" font-weight="700" letter-spacing="-0.4">\(escape(title))</text>
        """
        if let note {
            svg += """

              <text class="ig-muted" x="\(width - margin)" y="\(titleBaseline)" font-size="11" text-anchor="end">\(escape(note))</text>
            """
        }
        svg += """

          <rect class="ig-rule" x="\(margin)" y="\(ruleTop)" width="\(contentWidth)" height="\(ruleHeight)"/>
        """
        return svg
    }

    /// A layout coordinate as a whole pixel, rounded; `0` for a value that is not a finite coordinate.
    static func pixel(_ value: Double) -> Int {
        guard value.isFinite, abs(value) < 100_000 else { return 0 }
        return Int(value.rounded())
    }

    /// A layout coordinate as a whole pixel, rounded down.
    static func pixelFloor(_ value: Double) -> Int {
        guard value.isFinite, abs(value) < 100_000 else { return 0 }
        return Int(value.rounded(.down))
    }

    /// Escapes text for XML.
    static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
