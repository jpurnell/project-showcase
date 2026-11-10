//
//  Settlement.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Foundation

/// Whether a page's prose has been settled by hand and must not be regenerated.
///
/// A page the owner has edited carries `settled: true` in its frontmatter. Sync still refreshes its
/// infographics, which are facts about the repository, but never overwrites the narrative.
/// Remove the flag to hand the page back to the generator.
public enum Settlement {

    /// - Parameter existingPage: The page's current markdown, or `nil` when there is none yet.
    /// - Returns: `true` only when the frontmatter says `settled: true` (any case).
    public static func isSettled(existingPage: String?) -> Bool {
        guard let page = existingPage,
              let value = FrontmatterReader.value(for: "settled", in: page) else { return false }
        return value.lowercased() == "true"
    }
}
