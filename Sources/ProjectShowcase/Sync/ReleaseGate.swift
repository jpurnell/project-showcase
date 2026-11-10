//
//  ReleaseGate.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Foundation

/// Decides whether a repository has moved far enough to be worth a new narrative.
///
/// A page is rewritten when the project's newest release is at least a minor bump (`x.Y.0`) past
/// the one the page was last written from. Commits and patch releases refresh the graphics only.
public enum ReleaseGate {

    private struct Version: Comparable {
        let major: Int, minor: Int, patch: Int
        static func < (a: Version, b: Version) -> Bool {
            (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
        }
    }

    private static func parse(_ tag: String) -> Version? {
        let core = tag.drop { $0 == "v" || $0 == "V" }.split(separator: "-", maxSplits: 1).first ?? ""
        let parts = core.split(separator: ".").map { Int($0) }
        guard parts.count >= 1, parts.count <= 3, !parts.contains(nil) else { return nil }
        let n = parts.compactMap { $0 }
        return Version(major: n[0], minor: n.count > 1 ? n[1] : 0, patch: n.count > 2 ? n[2] : 0)
    }

    /// The highest version among `tags`, as written, or `nil` when none parses.
    public static func latestVersion(in tags: [String]) -> String? {
        tags.compactMap { tag in parse(tag).map { (tag, $0) } }.max { $0.1 < $1.1 }?.0
    }

    /// Whether `latest` is a minor or major bump past `recorded`.
    ///
    /// - Parameters:
    ///   - recorded: The newest release when the page was last written. `nil` means the page
    ///     predates this record, so it is regenerated once; an empty string means the project had
    ///     no release then.
    ///   - latest: The newest release now, or `nil` when there is none.
    public static func warrantsRegeneration(recorded: String?, latest: String?) -> Bool {
        guard let recorded else { return true }
        guard let latest, let now = parse(latest) else { return false }
        guard let before = parse(recorded) else { return true }
        return now.major > before.major || (now.major == before.major && now.minor > before.minor)
    }
}
