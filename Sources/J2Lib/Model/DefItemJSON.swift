//
//  DefJSON.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

// Bits to do with creating the decl-json product

extension DefItem {
    private enum CodingKeys: CodingKey {
        case location
        case kind
        case swiftName
        case objCName
        case swiftDeclaration
        case objCDeclaration
        case documentation
    }

    // I may well have got this wrong, but I am using classes here - can't see
    // how to use the auto-gen encode code for the derived class fields.
    final func doEncode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location, forKey: .location)
        try container.encode(defKind.key, forKey: .kind)
        try container.encodeIfPresent(swiftName, forKey: .swiftName)
        try container.encodeIfPresent(objCName, forKey: .objCName)
        try container.encodeIfPresent(swiftDeclaration, forKey: .swiftDeclaration)
        try container.encodeIfPresent(objCDeclaration, forKey: .objCDeclaration)
        if !documentation.isEmpty {
            try container.encode(documentation, forKey: .documentation)
        }
    }
}

extension Array where Element == DefItem {
    public func toJSON() throws -> String {
        try JSON.encode(self)
    }
}
