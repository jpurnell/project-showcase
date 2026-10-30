//
//  Discovery.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-10-30.
//

import Foundation

/// What a local checkout says about itself, as far as discovery needs.
public struct RepoFacts: Sendable, Equatable {
    /// Absolute path of the checkout.
    public let path: String
    /// Directory name.
    public let name: String
    /// Commits reachable from `HEAD`.
    public let commitCount: Int
    /// Date of the newest commit.
    public let lastCommit: Date
    /// `owner/repo` of the `origin` remote, lowercased, when it is a GitHub repository.
    public let remoteSlug: String?
    /// Whether the repo has a master plan that describes the project.
    public let hasMasterPlan: Bool

    /// Creates facts for one checkout.
    public init(path: String, name: String, commitCount: Int, lastCommit: Date, remoteSlug: String?, hasMasterPlan: Bool) {
        self.path = path
        self.name = name
        self.commitCount = commitCount
        self.lastCommit = lastCommit
        self.remoteSlug = remoteSlug
        self.hasMasterPlan = hasMasterPlan
    }
}

/// What GitHub says about a public repository.
public struct RemoteRepo: Sendable, Equatable {
    /// Whether the repository is a fork of someone else's.
    public let isFork: Bool
    /// Whether the repository is archived.
    public let isArchived: Bool

    /// Creates a record.
    public init(isFork: Bool, isArchived: Bool) {
        self.isFork = isFork
        self.isArchived = isArchived
    }
}

/// Turns a git remote URL into an `owner/repo` slug.
public enum RemoteSlug {

    /// The lowercased `owner/repo` of a GitHub remote, or `nil` for anything else.
    public static func parse(_ remote: String) -> String? {
        var text = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["git@github.com:", "https://github.com/", "ssh://git@github.com/"] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            while text.hasSuffix("/") { text.removeLast() }
            if text.hasSuffix(".git") { text.removeLast(4) }
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty }) else { return nil }
            return text.lowercased()
        }
        return nil
    }
}

/// Reads the public repositories of an owner through the GitHub CLI.
public enum GitHubRepoList {

    private struct Row: Decodable {
        let nameWithOwner: String
        let isFork: Bool
        let isArchived: Bool
    }

    /// Parses the JSON `gh repo list --json nameWithOwner,isFork,isArchived` prints.
    ///
    /// - Throws: A decoding error for output that is not that JSON, so a failed call is never
    ///   mistaken for an owner with no public repositories.
    public static func parse(_ data: Data) throws -> [String: RemoteRepo] {
        let rows = try JSONDecoder().decode([Row].self, from: data)
        return Dictionary(
            rows.map { ($0.nameWithOwner.lowercased(), RemoteRepo(isFork: $0.isFork, isArchived: $0.isArchived)) },
            uniquingKeysWith: { first, _ in first })
    }

    /// The absolute path of `gh`, searched on `PATH` and in the usual install locations.
    ///
    /// Resolved here because the subprocess kernel takes an absolute executable path, and a job
    /// started by launchd has a minimal `PATH`.
    static func locateCLI() throws -> String {
        let fromPath = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":").map { "\($0)/gh" }
        let candidates = fromPath + ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
        guard let found = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw ShowcaseError.extractionFailed(source: "gh", message: "the GitHub CLI (gh) is not installed")
        }
        return found
    }

    /// Lists `owner`'s public repositories.
    ///
    /// - Throws: ``ShowcaseError/extractionFailed(source:message:)`` when `gh` fails, for
    ///   instance because it is not signed in.
    public static func publicRepos(owner: String) throws -> [String: RemoteRepo] {
        let result = try ProcessRunner.run(
            try locateCLI(),
            arguments: ["repo", "list", owner, "--visibility", "public", "--limit", "1000",
                        "--json", "nameWithOwner,isFork,isArchived"],
            // gh finds its login through HOME and the keychain session, so it needs the
            // parent's environment; the kernel's default is an empty one.
            environment: ProcessInfo.processInfo.environment,
            timeout: .seconds(60)
        )
        guard result.didSucceed else {
            throw ShowcaseError.extractionFailed(source: "gh", message: "gh repo list exited \(result.exitStatus): \(result.standardError)")
        }
        return try parse(Data(result.standardOutput.utf8))
    }
}

/// The rules a repository must meet to be proposed as a showcase page.
public struct DiscoveryPolicy: Sendable, Equatable {
    /// Fewest commits a repository may have.
    public let minCommits: Int
    /// Oldest its newest commit may be, in days.
    public let maxAgeDays: Int
    /// Most proposals one run may return, so spend per run is bounded.
    public let maxNew: Int

    /// Creates a policy.
    public init(minCommits: Int, maxAgeDays: Int, maxNew: Int) {
        self.minCommits = minCommits
        self.maxAgeDays = maxAgeDays
        self.maxNew = maxNew
    }
}

/// Decides which local repositories deserve a showcase page.
public enum Discovery {

    /// Proposes repositories for the manifest.
    ///
    /// A repository qualifies only if GitHub lists it as public under `owner`, it is not a fork
    /// or archived, it has a master plan, and it meets the policy's size and recency floors. A
    /// repository with no GitHub remote is rejected because nothing says it is public.
    ///
    /// - Parameters:
    ///   - repos: Local checkouts.
    ///   - publicRepos: `owner/repo` (lowercased) to GitHub's facts, for public repositories only.
    ///   - owner: Whose repositories may be proposed.
    ///   - policy: The size, recency and count limits.
    ///   - coveredRemotes: Remotes an existing page already covers.
    ///   - existingSlugs: Slugs already in the manifest.
    ///   - now: The reference date for recency.
    /// - Returns: Qualifying repositories, most history first, at most `policy.maxNew`.
    public static func propose(
        repos: [RepoFacts],
        publicRepos: [String: RemoteRepo],
        owner: String,
        policy: DiscoveryPolicy,
        coveredRemotes: Set<String>,
        existingSlugs: Set<String>,
        now: Date
    ) -> [RepoFacts] {
        let ownerPrefix = owner.lowercased() + "/"
        let cutoff = now.addingTimeInterval(-Double(policy.maxAgeDays) * 86_400)
        var seenRemotes = coveredRemotes
        var seenSlugs = existingSlugs
        var proposed: [RepoFacts] = []

        let ranked = repos.sorted { $0.commitCount > $1.commitCount }
        for repo in ranked {
            guard let remote = repo.remoteSlug, remote.hasPrefix(ownerPrefix),
                  let remoteFacts = publicRepos[remote],
                  !remoteFacts.isFork, !remoteFacts.isArchived,
                  repo.hasMasterPlan,
                  repo.commitCount >= policy.minCommits,
                  repo.lastCommit >= cutoff,
                  !seenRemotes.contains(remote),
                  let slug = slug(for: repo.name), !seenSlugs.contains(slug)
            else { continue }
            seenRemotes.insert(remote)
            seenSlugs.insert(slug)
            proposed.append(repo)
            if proposed.count == policy.maxNew { break }
        }
        return proposed
    }

    /// A lowercase file stem for a repository name, or `nil` when nothing usable remains.
    public static func slug(for name: String) -> String? {
        var slug = ""
        for character in name.lowercased() {
            if character.isLetter || character.isNumber || character == "-" {
                slug.append(character)
            } else if !slug.hasSuffix("-") {
                slug.append("-")
            }
        }
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? nil : slug
    }

    /// `path` relative to `base` when it lies strictly under it, otherwise `path` unchanged.
    ///
    /// Components are compared ignoring case, because the same folder is spelled differently
    /// depending on how it was reached on a case-insensitive volume.
    public static func relativePath(of path: String, from base: URL) -> String {
        let target = URL(fileURLWithPath: path).standardizedFileURL.pathComponents
        let root = base.standardizedFileURL.pathComponents
        guard target.count > root.count,
              zip(target, root).allSatisfy({ $0.caseInsensitiveCompare($1) == .orderedSame })
        else { return path }
        return target.dropFirst(root.count).joined(separator: "/")
    }

    /// The manifest entry for a proposed repository, with the standard audience and style.
    public static func entry(for repo: RepoFacts, relativePath: String) -> SyncEntry? {
        guard let slug = slug(for: repo.name) else { return nil }
        return SyncEntry(
            slug: slug, path: relativePath, name: nil, group: nil,
            tags: ["showcase", repo.name.lowercased(), Audience.selfReflection.rawValue],
            audience: .selfReflection, style: .caseStudy)
    }
}
