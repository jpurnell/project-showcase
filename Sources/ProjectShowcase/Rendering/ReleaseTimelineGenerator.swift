//
//  ReleaseTimelineGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates a release timeline from a ``ProjectCard``: one tick per release at its date, on the
/// same axis as the commit chart, with a label only where one fits.
public struct ReleaseTimelineGenerator: InfographicGenerator, Sendable {

    /// The time zone the axis is laid out in; see ``CommitTimelineGenerator``.
    public let timeZone: TimeZone
    /// The locale month names are written in.
    public let locale: Locale

    /// Creates a generator. Both default to the values the commit chart uses, so the two share an axis.
    public init(
        timeZone: TimeZone = .gmt,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) {
        self.timeZone = timeZone
        self.locale = locale
    }

    /// Generates a release timeline from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let height = 132
        let baseline = 94
        let releases = card.git.releaseHistory
        let title = "\(card.projectName) — Releases"
        let label = "\(card.projectName) release history"

        guard !releases.isEmpty else {
            return InfographicChrome.opening(height: height, label: label, title: title, note: "none yet")
                + """

                  <text class="ig-muted" x="\(InfographicChrome.width / 2)" y="\(baseline)" font-size="13" text-anchor="middle">No releases yet</text>
                </svg>
                """
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale

        let dated = releases.compactMap { release in release.date.map { (tag: release.tag, date: $0) } }
        let scale = TimelineScale(card: card, calendar: calendar, left: InfographicChrome.left, right: InfographicChrome.right)

        // Where each release sits. With no dates at all they are spread evenly, oldest first.
        let placed: [(tag: String, x: Double)]
        if let scale, !dated.isEmpty {
            placed = dated.map { ($0.tag, scale.x(for: $0.date)) }
        } else {
            let span = InfographicChrome.right - InfographicChrome.left
            placed = releases.reversed().enumerated().map { index, release in
                (release.tag, InfographicChrome.left + span * (Double(index) + 0.5) / Double(releases.count))
            }
        }

        let newest = dated.max { $0.date < $1.date }?.tag ?? releases[0].tag
        let noun = releases.count == 1 ? "release" : "releases"
        var svg = InfographicChrome.opening(
            height: height, label: label, title: title, note: "\(releases.count) \(noun) · latest \(newest)")

        svg += """

          <line class="ig-hair" x1="\(InfographicChrome.pixel(InfographicChrome.left))" y1="\(baseline)" x2="\(InfographicChrome.pixel(InfographicChrome.right))" y2="\(baseline)"/>
        """
        for release in placed {
            svg += """

              <rect class="ig-bar" x="\(InfographicChrome.pixel(release.x) - 1)" y="\(baseline - 16)" width="2" height="16"/>
            """
        }

        for named in labelled(placed, newest: newest) {
            svg += """

              <text class="ig-label" x="\(InfographicChrome.pixel(named.x))" y="\(baseline - 24)" font-size="11" font-weight="700" text-anchor="middle">\(InfographicChrome.escape(named.tag))</text>
            """
        }

        if let scale {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = timeZone
            formatter.locale = locale
            formatter.dateFormat = "MMM"
            for axis in scale.axisLabels(monthFormatter: formatter) {
                svg += """

                  <text class="ig-muted" x="\(InfographicChrome.pixel(axis.x))" y="\(baseline + 18)" font-size="10" text-anchor="middle">\(axis.text)</text>
                """
            }
        }

        svg += "\n</svg>"
        return svg
    }

    /// The releases that get a label, and where.
    ///
    /// The newest and the oldest first, then major versions, newest first; each only if it fits
    /// beside the ones already chosen. Labelling all of twenty-six releases would print them over
    /// one another, and the ticks already show where each one is.
    private func labelled(_ placed: [(tag: String, x: Double)], newest: String) -> [(tag: String, x: Double)] {
        guard let oldest = placed.min(by: { $0.x < $1.x }) else { return [] }
        let latest = placed.first { $0.tag == newest } ?? placed.max { $0.x < $1.x }
        let byNewest = placed.sorted { $0.x > $1.x }
        let candidates = ([latest, oldest].compactMap { $0 }) + byNewest.filter { Self.isMajor($0.tag) }

        var chosen: [(tag: String, x: Double, half: Double)] = []
        for candidate in candidates where candidate.x.isFinite && !chosen.contains(where: { $0.tag == candidate.tag }) {
            let half = Double(candidate.tag.count) * 6.5 / 2 + 3
            // Keep the text inside the chart.
            let lowest = InfographicChrome.left + half
            let highest = InfographicChrome.right - half
            let centre = candidate.x < lowest ? lowest : (candidate.x > highest ? highest : candidate.x)
            let fits = chosen.allSatisfy { abs($0.x - centre) >= $0.half + half + 8 }
            if fits { chosen.append((candidate.tag, centre, half)) }
        }
        return chosen.map { ($0.tag, $0.x) }
    }

    /// Whether a tag is a major version: `1.0`, `v2.0.0`, but not `2.1` or `3.0.1`.
    static func isMajor(_ tag: String) -> Bool {
        let bare = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let parts = bare.split(separator: ".")
        guard let first = parts.first.flatMap({ Int($0) }), first >= 1 else { return false }
        return parts.dropFirst().allSatisfy { Int($0) == 0 }
    }
}
