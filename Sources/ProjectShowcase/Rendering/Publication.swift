//
//  Publication.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Foundation

/// Whether a page is published, as decided by the person who owns the site.
///
/// `published:` is an editorial decision, not a fact about a repository, so regenerating a page
/// must not reset it. Only an explicit `false` withholds a page.
public enum Publication {

    /// The publication state an existing page asks for.
    ///
    /// - Parameter existingPage: The page's current markdown, or `nil` when there is none yet.
    /// - Returns: `false` only if the page's frontmatter says `published: false` (any case);
    ///   `true` for a new page, a page with no flag, or a value that is not `false`.
    public static func isPublished(existingPage: String?) -> Bool {
        guard let page = existingPage,
              let value = FrontmatterReader.value(for: "published", in: page) else { return true }
        return value.lowercased() != "false"
    }
}
