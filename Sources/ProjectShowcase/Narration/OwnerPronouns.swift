//
//  OwnerPronouns.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-11-10.
//

import Foundation

/// The pronouns the site's owner uses, as the narrator is told to use them.
///
/// Read from `basics.pronouns` in the site's `cv.json`, so the owner states them once, in a field,
/// and no prompt or generated page has to guess. A name does not tell you someone's pronouns.
public struct OwnerPronouns: Codable, Equatable, Sendable {
    /// The subject form, as in "he wrote it".
    public let subject: String
    /// The object form, as in "thanks to him".
    public let object: String
    /// The possessive determiner, as in "his project".
    public let possessive: String

    /// Creates a set of pronouns.
    public init(subject: String, object: String, possessive: String) {
        self.subject = subject
        self.object = object
        self.possessive = possessive
    }

    /// The `cv.json` a site keeps beside its manifest: `<site>/Resources/cv.json`.
    public static func defaultCVURL(besideManifest manifest: URL) -> URL {
        manifest.deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("cv.json")
    }

    /// The pronouns in a `cv.json`'s `basics.pronouns`.
    ///
    /// - Returns: `nil` when the file does not exist or has no pronouns, so a site that has not
    ///   recorded them is told not to guess rather than refused.
    /// - Throws: When the file exists but is not valid JSON, or `pronouns` is present and malformed.
    ///   Silently dropping a stated preference would be worse than stopping.
    public static func load(fromCV url: URL) throws -> OwnerPronouns? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        struct Envelope: Decodable {
            struct Basics: Decodable { let pronouns: OwnerPronouns? }
            let basics: Basics?
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: Data(contentsOf: url))
        return envelope.basics?.pronouns
    }

    /// The instruction placed in a narrator's system prompt.
    public static func rule(for pronouns: OwnerPronouns?) -> String {
        guard let pronouns else {
            return "You do not know the author's pronouns. Do not guess them from a name: refer to the author by name, "
                + "with the singular \"they\", or without a pronoun."
        }
        return "The author uses \(pronouns.subject)/\(pronouns.object)/\(pronouns.possessive). When you refer to the author "
            + "in the third person, use exactly these (subject \"\(pronouns.subject)\", object \"\(pronouns.object)\", "
            + "possessive \"\(pronouns.possessive)\") and never guess others; in the first person no pronoun for the author is needed."
    }
}
