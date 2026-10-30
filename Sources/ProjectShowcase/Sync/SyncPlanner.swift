//
//  SyncPlanner.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-29.
//

import Foundation

/// The result of asking a source repository for its `HEAD`.
public enum HeadLookup: Sendable, Equatable {
    /// The commit id.
    case success(String)
    /// Why the commit id could not be read.
    case failure(String)
}

/// Why a page is, or is not, regenerated.
public enum SyncReason: Sendable, Equatable {
    /// No record of this page exists.
    case neverGenerated
    /// The source has commits the page was not generated from.
    case sourceMoved(from: String, to: String)
    /// The caller asked for every page to be regenerated.
    case forced
    /// The page already reflects the source's `HEAD`.
    case current
    /// The source could not be read, so nothing can be said about it.
    case sourceUnavailable(String)
}

/// What to do with one entry.
public enum SyncAction: Sendable, Equatable {
    /// Regenerate the page.
    case regenerate(reason: SyncReason)
    /// Leave the page alone.
    case skip(reason: SyncReason)
}

/// One entry and the decision made about it.
public struct SyncDecision: Sendable, Equatable {
    /// The manifest entry.
    public let entry: SyncEntry
    /// What to do with it.
    public let action: SyncAction
    /// The source `HEAD` the decision was made against, when it could be read.
    public let head: String?
}

/// Decides which pages are stale. Pure: it reads nothing and writes nothing.
public enum SyncPlanner {

    /// Plans a sync run.
    ///
    /// A source whose `HEAD` cannot be read is skipped even under `force`: regenerating a page
    /// from a repository that cannot be inspected would publish a narrative about nothing.
    public static func plan(
        entries: [SyncEntry],
        heads: [String: HeadLookup],
        state: SyncState,
        force: Bool
    ) -> [SyncDecision] {
        entries.map { entry in
            switch heads[entry.slug] {
            case .none:
                return SyncDecision(entry: entry, action: .skip(reason: .sourceUnavailable("no head resolved")), head: nil)
            case .some(.failure(let message)):
                return SyncDecision(entry: entry, action: .skip(reason: .sourceUnavailable(message)), head: nil)
            case .some(.success(let head)):
                guard let record = state.records[entry.slug] else {
                    return SyncDecision(entry: entry, action: .regenerate(reason: .neverGenerated), head: head)
                }
                if force {
                    return SyncDecision(entry: entry, action: .regenerate(reason: .forced), head: head)
                }
                if record.head == head {
                    return SyncDecision(entry: entry, action: .skip(reason: .current), head: head)
                }
                return SyncDecision(entry: entry, action: .regenerate(reason: .sourceMoved(from: record.head, to: head)), head: head)
            }
        }
    }

    /// Whether the card carries the project's own description of itself.
    ///
    /// Without one the narrative is inferred from names and file counts, which is how a rules
    /// engine for a strategy game was once described as an icon library. A published page is
    /// never replaced by output the card cannot support.
    public static func isGrounded(_ card: ProjectCard) -> Bool {
        guard let description = card.designArtifacts?.projectDescription else { return false }
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
