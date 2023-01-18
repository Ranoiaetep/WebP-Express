//
//  FileModel.swift
//  WebP Express
//
//  Created by Peter Cong on 1/18/23.
//

import Foundation

struct FileModel {
    enum ProcessingState
    {
        case success, fail, processing, unstarted
    }

    var url: URL
    var state: ProcessingState = .unstarted
}

extension FileModel: Identifiable {
    public var id: URL { url }
}

extension FileModel: Equatable {}

extension FileModel: Comparable {

    static func < (lhs: FileModel, rhs: FileModel) -> Bool {
        lhs.url < rhs.url
    }

}
