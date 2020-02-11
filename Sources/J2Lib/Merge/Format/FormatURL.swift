//
//  FormatURL.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Collect the routines for assigning and working with URLs.

private extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
    }

    var urlFragmentEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
    }

    var removingPercentEncoding: String {
        removingPercentEncoding!
    }
}

public struct URLPieces: Encodable {
    /// %-encoded URL path, without file extension
    public let urlPath: String
    /// %-encoded URL hash, or `nil` if no hash
    public let urlHash: String?

    /// Initialize for a top-level web page
    public init(pageName: String) {
        urlPath = pageName.urlPathEncoded
        urlHash = nil
    }

    /// Initialize for a nested web page
    public init(parentURLPath: String, pageName: String) {
        urlPath = parentURLPath + "/" + pageName.urlPathEncoded
        urlHash = nil
    }

    /// Initialize for an anchor on a web page
    public init(parentURLPath: String, hashName: String) {
        urlPath = parentURLPath
        urlHash = hashName.urlFragmentEncoded
    }

    init() {
        urlPath = ""
        urlHash = nil
    }

    /// Get the url (path + fragment/hash), assuming some file extension.  %-encoded for a URL.
    public func url(fileExtension: String) -> String {
        let path = urlPath + fileExtension
        return urlHash.flatMap { path + "#\($0)" } ?? path
    }

    /// Get the file-system name of the page, assuming some file extension.
    /// Invalid for hashes.
    public func filepath(fileExtension: String) -> String {
        precondition(urlHash == nil)
        return url(fileExtension: fileExtension).removingPercentEncoding
    }

    /// Get a path from this item's page back up to the doc root - either empty string or ends in a slash
    var pathToRoot: String {
        return String(repeating: "../", count: urlPath.directoryNestingDepth)
    }
}

extension Item {
    /// Set this item to be a top-level page in docs
    func setURLPath() {
        url = URLPieces(pageName: slug)
    }

    /// Set this item to be its own page in docs, nested under some parent page
    func setURLPath(parentURLPath: String) {
        url = URLPieces(parentURLPath: parentURLPath, pageName: slug)
    }

    /// Set this item to be embedded in some parent page
    func setURLHash(parentURLPath: String) {
        url = URLPieces(parentURLPath: parentURLPath, hashName: slug)
    }

    /// Does the item get its own page in the docs?  If not then it is inlined into its parent.
    var renderAsPage: Bool {
        url.urlHash == nil
    }
}

struct URLVisitor: ItemVisitor {
    func visit(defItem: DefItem, parents: [Item]) {
        guard let parent = parents.last else {
            preconditionFailure() // must be in a group at least
        }

        if defItem.children.isEmpty {
            // embed on parent page
            defItem.setURLHash(parentURLPath: parent.url.urlPath)
        } else if parent.kind == .group {
            // a top-level def, place according to kind
            // NOT THE PARENT!  PARENT MAY BE A NESTED CUSTOM CATEGORY.
            // XXX need to understand multi-module here
            defItem.setURLPath(parentURLPath: defItem.defKind.metaKind.name)
        } else {
            // we're a nested def with children, we go in our parent's directory
            defItem.setURLPath(parentURLPath: parent.url.urlPath)
        }
    }

    /// Groups all go in the top level using their slug as a name.
    func visit(groupItem: GroupItem, parents: [Item]) {
        groupItem.setURLPath()
    }
}