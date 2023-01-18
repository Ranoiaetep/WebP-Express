//
//  WebPExtension.swift
//  WebP Express
//
//  Created by Peter Cong on 1/18/23.
//

import Foundation
import WebP

extension WebPEncoderConfig.Preset: CaseIterable {
    public static var allCases: [WebPEncoderConfig.Preset] = [
        .default,
        .picture,
        .photo,
        .drawing,
        .icon,
        .text
    ]
}

extension WebPEncoderConfig.Preset: CustomStringConvertible {
    public var description: String {
        switch self {
        case .default:
            return "default"
        case .picture:
            return "picture"
        case .photo:
            return "photo"
        case .drawing:
            return "drawing"
        case .icon:
            return "icon"
        case .text:
            return "text"
        }
    }
}

extension WebPEncoderConfig.Preset: RawRepresentable {
    public init?(rawValue: String) {
        guard let result = Self.allCases.first(where: { $0.description == rawValue })
        else { return nil }
        self = result
    }
    public var rawValue: String { description }
}
