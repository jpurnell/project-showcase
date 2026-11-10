//
//  TimelineScale.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Foundation

/// One time axis for the commit and release charts, so a release lines up with the commits around it.
///
/// The axis runs from the earliest of the first commit and the first release to the latest of the
/// last commit and the last release, in whole months of the calendar it is given.
struct TimelineScale {
    /// The start of each month on the axis, oldest first.
    let months: [Date]
    /// The calendar, and so the time zone, the months were counted in.
    let calendar: Calendar
    /// Left edge of the axis.
    let left: Double
    /// Right edge of the axis.
    let right: Double

    /// Width of one month.
    var slot: Double {
        let count = Double(months.count)
        guard count > 0 else { return 0 }
        return (right - left) / count
    }

    /// The axis for a card, or `nil` when the card has no dates at all.
    init?(card: ProjectCard, calendar: Calendar, left: Double, right: Double) {
        let dates = [card.git.firstCommitDate, card.git.latestCommitDate].compactMap { $0 }
            + card.git.releaseHistory.compactMap(\.date)
        guard let start = dates.min(), let end = dates.max() else { return nil }
        let months = Self.months(from: start, to: end, calendar: calendar)
        guard !months.isEmpty else { return nil }
        self.months = months
        self.calendar = calendar
        self.left = left
        self.right = right
    }

    /// The start of every month from `start`'s through `end`'s.
    static func months(from start: Date, to end: Date, calendar: Calendar) -> [Date] {
        guard var current = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) else { return [] }
        var months: [Date] = []
        while current <= end {
            months.append(current)
            guard let next = calendar.date(byAdding: .month, value: 1, to: current), next > current else { break }
            current = next
        }
        return months.isEmpty ? [current] : months
    }

    /// Where a date falls on the axis, to the day.
    func x(for date: Date) -> Double {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let monthStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month)),
              let index = months.firstIndex(of: monthStart) else {
            return date < (months.first ?? date) ? left : right
        }
        let days = Double(calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30)
        guard days > 0 else { return left }
        return left + (Double(index) + Double((parts.day ?? 1) - 1) / days) * slot
    }

    /// The labels under the axis.
    ///
    /// Up to fourteen months the axis names months, thinned to about eight labels. Beyond that a month
    /// name repeats every year and says nothing about which, so each year is named at its January.
    func axisLabels(monthFormatter: DateFormatter) -> [(x: Double, text: String)] {
        let count = months.count
        return months.enumerated().compactMap { index, month in
            let centre = left + (Double(index) + 0.5) * slot
            if count > 14 {
                guard calendar.component(.month, from: month) == 1 else { return nil }
                return (centre, String(calendar.component(.year, from: month)))
            }
            let interval = max(count / 8, 1)
            guard index % interval == 0 || index == count - 1 else { return nil }
            return (centre, monthFormatter.string(from: month))
        }
    }
}
