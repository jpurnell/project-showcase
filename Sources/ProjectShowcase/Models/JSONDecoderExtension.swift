//
//  JSONDecoderExtension.swift
//  ProjectShowcase
//
//  Created by Justin Purnell on 2026-05-11.
//

import Foundation

extension JSONDecoder {
    /// Returns a JSONDecoder configured for ISO 8601 date decoding.
    public static func iso8601Configured() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
