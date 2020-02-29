//
//  Merge.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import SourceKittenFramework

/// `Merge` generates rich code definition data by combining gathered source-code data.
///
/// - discard stuff that didn't actually get compiled
/// - merge duplicates, combining availability
/// - resolve extensions and categories
///
/// This is the end of the sourcekit-style hashes, converted into more well-typed `Item` hierarchy.
public struct Merge: Configurable {
    let definitions: MergeDefinitions
    let filter: MergeFilter

    /// We unique names over the entire corpus which is unnecessary but makes life easier.
    var uniquer = StringUniquer()

    // Unit test controls
    var enableFilter = true
    var enablePhase2 = true

    public init(config: Config) {
        definitions = MergeDefinitions(config: config)
        filter = MergeFilter(config: config)
        config.register(self)
    }
    
    public func merge(gathered: [GatherModulePass]) throws -> [DefItem] {
        logDebug("Merge: import")
        var items = importItems(gathered: gathered)
        logDebug("Merge: merge phase 1")
        items = definitions.mergePhase1(items: items)
        if enableFilter {
            logDebug("Merge: filter")
            items = filter.filter(items: items)
        }
        if enablePhase2 {
            logDebug("Merge: merge phase 2")
            items = definitions.mergePhase2(items: items)
        }
        return items
    }
}
