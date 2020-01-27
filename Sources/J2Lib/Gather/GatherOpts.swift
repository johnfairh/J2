//
//  GatherConfig.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

struct GatherOpts : Configurable {
    let config: Config

    let moduleNameOpt = StringOpt(s: "m", l: "module", y: "module")

    init(config: Config) {
        self.config = config

        config.register(self)
    }

    func checkOptions() throws {
        guard moduleNameOpt.configured else {
            throw OptionsError("Missing 'module' option.") // temp
        }
    }

    var jobs: [GatherJob] {
        return [.swift(moduleName: moduleNameOpt.value)]
    }

    var configFileSearchStart: URL? {
        nil
    }
}
