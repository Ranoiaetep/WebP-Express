//
//  URLExtension.swift
//  WebP Express
//
//  Created by Peter Cong on 1/18/23.
//

import Foundation

extension URL: Identifiable {
    public var id: String { absoluteString }
}

extension URL {
    public var directory: String { deletingLastPathComponent().path(percentEncoded: false) }
}

extension URL: Comparable {
    public static func < (lhs: URL, rhs: URL) -> Bool {
        return lhs.absoluteString < rhs.absoluteString
    }
}
