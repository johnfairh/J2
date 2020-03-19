//
//  DefTopic.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The topics that definitions are automatically split into within a type.
/// The order of the enum matches the order on the page.
public enum DefTopic: CaseIterable {
    case associatedType
    case type
    case initializer
    case deinitializer
    case enumElement
    case method
    case property
    case field
    case `subscript`
    case staticMethod
    case staticProperty
    case staticSubscript
    case classMethod
    case classProperty
    case classSubscript
    case other

    private var nameKey: L10n.Output {
        .types
    }

    var name: Localized<String> {
        .localizedOutput(nameKey)
    }
}
