//
//  GatherConfig.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Type  responsible for declaring and parsing the config options.
///
/// Its output is a set of `GatherJob`s that are self-contained recipes on how to
/// create a `GatherModulePass`.
///
/// The main interesting piece here is dealing with `modules`.
struct GatherOpts : Configurable {
    let config: Config

    let moduleNameOpt = StringOpt(s: "m", l: "module", y: "module")
    let srcDirOpt = PathOpt(l: "source-directory", y: "source_directory")

    init(config: Config) {
        self.config = config

        config.register(self)
    }

    func checkOptions() throws {
    }

    var jobs: [GatherJob] {
        return [.swift(moduleName: moduleNameOpt.value, srcDir: srcDirOpt.value)]
    }

    var configFileSearchStart: URL? {
        srcDirOpt.value
    }
}