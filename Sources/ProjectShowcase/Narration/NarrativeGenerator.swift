//
//  NarrativeGenerator.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

/// Generates narrative portfolio entries by calling the Claude API.
public struct NarrativeGenerator: Sendable {

    /// Whether `url` may receive the API key: Anthropic's own host or a subdomain of it over HTTPS,
    /// or `localhost` for a local proxy.
    ///
    /// The check was `host.hasSuffix("anthropic.com")`, which admits `evilanthropic.com`; the
    /// request that follows carries the key in `x-api-key`. A subdomain is matched with its dot.
    ///
    /// - Parameter url: The endpoint built from the configured base URL.
    /// - Returns: `true` only for the hosts above.
    static func isAllowedEndpoint(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased(), let scheme = url.scheme?.lowercased() else { return false }
        if host == "localhost" { return scheme == "http" || scheme == "https" }
        guard scheme == "https" else { return false }
        return host == "anthropic.com" || host.hasSuffix(".anthropic.com")
    }

    private let apiKey: String
    private let model: String
    private let baseURL: String

    /// Creates a new NarrativeGenerator with the given API key and optional model/base URL.
    public init(
        apiKey: String,
        model: String = "claude-sonnet-4-6",
        baseURL: String = "https://api.anthropic.com"
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
    }

    /// Generate a narrative from a ProjectCard.
    public func generate(
        card: ProjectCard,
        audience: Audience,
        style: NarrativeStyle,
        priorNarrative: NarrativeResult? = nil
    ) async throws -> NarrativeResult {
        let builder = PromptBuilder()
        let systemPrompt = try builder.buildSystemPrompt(audience: audience, style: style)
        let userPrompt = try builder.buildUserPrompt(from: card)
        let cardHash = try builder.cardHash(for: card)

        if let prior = priorNarrative, prior.cardHash == cardHash {
            return prior
        }

        let text = try await callAPI(systemPrompt: systemPrompt, userPrompt: userPrompt)

        let parser = NarrativeResponseParser()
        return try parser.parse(
            response: text,
            projectName: card.projectName,
            audience: audience,
            style: style,
            cardHash: cardHash
        )
    }

    /// Generate a portfolio overview from multiple ProjectCards.
    public func generatePortfolio(
        cards: [ProjectCard],
        audience: Audience
    ) async throws -> String {
        let builder = PortfolioPromptBuilder()
        let systemPrompt = try builder.buildSystemPrompt(audience: audience)
        let userPrompt = try builder.buildUserPrompt(from: cards)

        return try await callAPI(systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    private func callAPI(systemPrompt: String, userPrompt: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]

        let urlString = "\(baseURL)/v1/messages"
        // SECURITY: the host is checked by isAllowedEndpoint below before the API key is attached
        guard let url = URL(string: urlString), Self.isAllowedEndpoint(url) else {
            throw ShowcaseError.narrativeGenerationFailed(
                message: "Invalid or disallowed API URL: \(urlString)"
            )
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ShowcaseError.narrativeGenerationFailed(message: "Invalid response type")
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw ShowcaseError.narrativeGenerationFailed(
                message: "API returned \(httpResponse.statusCode): \(body)"
            )
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw ShowcaseError.narrativeGenerationFailed(message: "Could not parse API response")
        }

        return text
    }
}
