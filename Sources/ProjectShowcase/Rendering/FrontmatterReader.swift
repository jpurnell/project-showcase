//
//  FrontmatterReader.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Foundation

/// Reads single-line values from a page's YAML frontmatter.
public enum FrontmatterReader {

    /// The value of `key` in the frontmatter block, or `nil` when the page has no frontmatter or
    /// the key appears only below it.
    public static func value(for key: String, in markdown: String) -> String? {
        let lines = markdown.lines
        guard lines.first == "---" else { return nil }
        let prefix = "\(key):"
        for line in lines.dropFirst() {
            if line == "---" { return nil }
            if line.hasPrefix(prefix) {
                let value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
        }
        return nil
    }
}
