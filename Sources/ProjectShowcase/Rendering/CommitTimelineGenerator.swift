//
//  CommitTimelineGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates a horizontal bar chart SVG showing commit activity over time.
public struct CommitTimelineGenerator: InfographicGenerator, Sendable {

    /// The time zone a commit's month is read in.
    private let timeZone: TimeZone

    /// The locale the month labels are written in.
    private let locale: Locale

    /// Creates a generator that counts and labels months in a stated time zone and locale.
    ///
    /// Neither is taken from the machine. A commit made at 02:00 UTC on the first of a month
    /// belongs to the previous month anywhere west of Greenwich, so a generator that asked the
    /// system would draw a different chart for the same repository depending on where it ran —
    /// and the chart is a file that gets committed.
    ///
    /// - Parameters:
    ///   - timeZone: The zone month boundaries fall in. UTC by default, matching the dates
    ///     ``MarkdownRenderer`` writes.
    ///   - locale: The locale of the abbreviated month names. `en_US_POSIX` by default, whose
    ///     names do not vary with the system's settings.
    public init(
        timeZone: TimeZone = .gmt,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) {
        self.timeZone = timeZone
        self.locale = locale
    }

    /// Generates a commit activity timeline SVG from the given project card.
    public func generate(from card: ProjectCard) throws -> String {
        let width = 600
        let height = 200
        let bgColor = "#1a1a2e"
        let barColor = "#00d4ff"
        let labelColor = "#8892b0"
        let titleColor = "#e0e0e0"
        let chartLeft = 40
        let chartRight = width - 40
        let chartTop = 55
        let chartBottom = height - 40
        let chartWidth = chartRight - chartLeft
        let chartHeight = chartBottom - chartTop

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)">
          <rect x="0" y="0" width="\(width)" height="\(height)" rx="10" ry="10" fill="\(bgColor)"/>
          <text x="\(width / 2)" y="32" font-family="sans-serif" font-size="16" font-weight="bold" fill="\(titleColor)" text-anchor="middle">\(escapeXML(card.projectName)) — Commit Activity</text>
        """

        guard let firstDate = card.git.firstCommitDate,
              let latestDate = card.git.latestCommitDate else {
            // No date info — show placeholder with commit count
            svg += """

              <rect x="\(chartLeft)" y="\(chartTop)" width="\(chartWidth)" height="\(chartHeight)" rx="4" ry="4" fill="\(barColor)" opacity="0.7"/>
              <text x="\(width / 2)" y="\(chartTop + chartHeight / 2 + 5)" font-family="sans-serif" font-size="14" fill="\(bgColor)" font-weight="bold" text-anchor="middle">\(card.git.commitCount) commits</text>
            </svg>
            """
            return svg
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        let months = monthsBetween(start: firstDate, end: latestDate, calendar: calendar)

        guard months.count > 0 else {
            svg += """

              <rect x="\(chartLeft)" y="\(chartTop)" width="\(chartWidth)" height="\(chartHeight)" rx="4" ry="4" fill="\(barColor)" opacity="0.7"/>
              <text x="\(width / 2)" y="\(chartTop + chartHeight / 2 + 5)" font-family="sans-serif" font-size="14" fill="\(bgColor)" font-weight="bold" text-anchor="middle">\(card.git.commitCount) commits</text>
            </svg>
            """
            return svg
        }

        let commitsPerMonth = max(card.git.commitCount / months.count, 1)
        let maxBarHeight = chartHeight - 20
        let barSpacing = 2
        let totalBarSpace = chartWidth - (barSpacing * (months.count - 1))
        let barWidth = max(totalBarSpace / months.count, 4)

        // The same calendar, zone and locale the months were counted in: a label formatted in
        // another zone would name the month before the one its bar stands for.
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.locale = locale
        formatter.dateFormat = "MMM"

        for (index, month) in months.enumerated() {
            let x = chartLeft + index * (barWidth + barSpacing)
            let barHeight = maxBarHeight
            let y = chartBottom - barHeight

            svg += """

              <rect x="\(x)" y="\(y)" width="\(barWidth)" height="\(barHeight)" rx="2" ry="2" fill="\(barColor)" opacity="0.8"/>
            """

            // Show month label (skip some if too many)
            let labelInterval = max(months.count / 8, 1)
            if index % labelInterval == 0 || index == months.count - 1 {
                let label = formatter.string(from: month)
                svg += """

                <text x="\(x + barWidth / 2)" y="\(chartBottom + 14)" font-family="sans-serif" font-size="9" fill="\(labelColor)" text-anchor="middle">\(label)</text>
                """
            }
        }

        // Commit count annotation
        svg += """

          <text x="\(chartRight)" y="\(chartTop - 5)" font-family="sans-serif" font-size="10" fill="\(labelColor)" text-anchor="end">~\(commitsPerMonth)/month (\(card.git.commitCount) total)</text>
        </svg>
        """

        return svg
    }

    private func monthsBetween(start: Date, end: Date, calendar: Calendar) -> [Date] {
        var months: [Date] = []
        let startComps = calendar.dateComponents([.year, .month], from: start)
        let endComps = calendar.dateComponents([.year, .month], from: end)

        guard let startMonth = calendar.date(from: startComps) else {
            return [start]
        }

        var current = startMonth
        while current <= end {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else {
                break
            }
            if next <= current { break }
            current = next

            let currentComps = calendar.dateComponents([.year, .month], from: current)
            if let cy = currentComps.year, let cm = currentComps.month,
               let ey = endComps.year, let em = endComps.month {
                if cy > ey || (cy == ey && cm > em) {
                    break
                }
            }
        }

        if months.isEmpty {
            months.append(start)
        }

        return months
    }

    private func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
