//
//  CommitTimelineGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates commits per month as bars, from a ``ProjectCard``.
public struct CommitTimelineGenerator: InfographicGenerator, Sendable {

    /// The time zone months are counted in. UTC by default, so the same card draws the same chart
    /// on any machine.
    public let timeZone: TimeZone
    /// The locale month names are written in.
    public let locale: Locale

    /// Creates a generator.
    /// - Parameters:
    ///   - timeZone: The zone months are counted in; a commit near midnight on the first of a month
    ///     belongs to different months in different zones.
    ///   - locale: The locale month labels are formatted in; fixed so the output does not vary with
    ///     the system's settings.
    public init(
        timeZone: TimeZone = .gmt,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) {
        self.timeZone = timeZone
        self.locale = locale
    }

    /// Generates a commit activity chart from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let height = 172
        let chartTop = InfographicChrome.contentTop
        let chartBottom = 148
        let total = card.git.commitCount

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale

        guard let scale = TimelineScale(
            card: card, calendar: calendar, left: InfographicChrome.left, right: InfographicChrome.right) else {
            return InfographicChrome.opening(
                height: height, label: "\(card.projectName) commit activity by month",
                title: "\(card.projectName) — Commit Activity", note: "~\(total) commits")
                + "\n</svg>"
        }

        // Commits per month, counted in the calendar the axis was laid out in. A card gathered
        // before commit dates were recorded has none, and then no bar is drawn: equal bars would
        // claim every month was as busy as the next.
        var countByMonth: [Date: Int] = [:]
        for commit in card.git.commitDates ?? [] {
            if let month = calendar.date(from: calendar.dateComponents([.year, .month], from: commit)) {
                countByMonth[month, default: 0] += 1
            }
        }
        let peak = scale.months.map { countByMonth[$0] ?? 0 }.max() ?? 0
        let perMonth = max(total / scale.months.count, 1)
        let peakText = peak > 0 ? " · peak \(peak)" : ""

        var svg = InfographicChrome.opening(
            height: height, label: "\(card.projectName) commit activity by month",
            title: "\(card.projectName) — Commit Activity",
            note: "~\(perMonth)/month\(peakText) (\(total) total)")

        // Thin the gaps on a long history, where fixed gaps would eat the bars.
        let gap = scale.months.count > 40 ? 1.0 : 2.0
        let maxBarHeight = chartBottom - chartTop
        for (index, month) in scale.months.enumerated() {
            let count = countByMonth[month] ?? 0
            guard count > 0, peak > 0 else { continue }
            let x = InfographicChrome.pixelFloor(scale.left + Double(index) * scale.slot + gap / 2)
            let width = max(InfographicChrome.pixelFloor(scale.slot - gap), 1)
            // At least one pixel, so a single commit is still visible.
            let barHeight = max(maxBarHeight * count / peak, 1)
            svg += """

              <rect class="ig-bar" x="\(x)" y="\(chartBottom - barHeight)" width="\(width)" height="\(barHeight)"/>
            """
        }

        svg += """

          <line class="ig-hair" x1="\(InfographicChrome.pixel(scale.left))" y1="\(chartBottom)" x2="\(InfographicChrome.pixel(scale.right))" y2="\(chartBottom)"/>
        """

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = "MMM"
        for label in scale.axisLabels(monthFormatter: formatter) {
            svg += """

              <text class="ig-muted" x="\(InfographicChrome.pixel(label.x))" y="\(chartBottom + 18)" font-size="10" text-anchor="middle">\(label.text)</text>
            """
        }

        svg += "\n</svg>"
        return svg
    }
}
