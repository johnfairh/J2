//
//  GatherJobOpts.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

/// The common option set that can be set at outer, module, or module-pass level.
/// These are the options that fundamentally generate `GatherJob`s.
struct GatherJobOpts: Configurable {
    let srcDirOpt = PathOpt(l: "source-directory").help("DIRPATH")
    let buildToolOpt = EnumOpt<Gather.BuildTool>(l: "build-tool")
    let buildToolArgsOpt = StringListOpt(s: "b", l: "build-tool-arguments").help("ARG1,ARG2...")
    let availabilityDefaultsOpt = StringListOpt(l: "availability-defaults").help("AVAILABILITY1,AVAILABILITY2,...")
    let ignoreAvailabilityAttrOpt = BoolOpt(l: "ignore-availability-attr")

    let objcDirectOpt = BoolOpt(l: "objc-direct")
    let objcHeaderFileOpt = PathOpt(l: "objc-header-file").help("HEADERPATH")
    let objcIncludePathsOpt = PathListOpt(l: "objc-include-paths").help("INCLUDEDIRPATH1,INCLUDEDIRPATH2,...")
    let objcSdkOpt = EnumOpt<Gather.Sdk>(l: "objc-sdk").def(.macosx)

    /// First pass of options-checking, that individual things entered are valid
    func checkOptions(published: Config.Published) throws {
        try srcDirOpt.checkIsDirectory()
        try objcHeaderFileOpt.checkIsFile()
        try objcIncludePathsOpt.checkAreDirectories()
    }

    /// Update configuration from a parent set that we're specializing
    func cascade(from: GatherJobOpts, debug: String) throws {
        // srcdir: always cascade
        if from.srcDirOpt.configured && !srcDirOpt.configured {
            logDebug("Gather: \(debug) srcDir")
            srcDirOpt.set(string: from.srcDirOpt.configStringValue!, path: from.srcDirOpt.value!)
        }
        // buildtool: don't cascade if objcdirect [mutually exclusive]
        //            don't cascade if objcheaderfile [not implemented]
        if from.buildToolOpt.configured && !buildToolOpt.configured && !objcDirectOpt.configured && !objcHeaderFileOpt.configured{
            logDebug("Gather: \(debug) buildTool")
            try buildToolOpt.set(string: from.buildToolOpt.value!.rawValue)
        }
        // buildtoolargs: always cascade
        if from.buildToolArgsOpt.configured && !buildToolArgsOpt.configured {
            logDebug("Gather: \(debug) buildToolArgs")
            from.buildToolArgsOpt.value.forEach { buildToolArgsOpt.set(string: $0) }
        }
        // availability: always cascade
        if from.availabilityDefaultsOpt.configured && !availabilityDefaultsOpt.configured {
            logDebug("Gather: \(debug) availabilityDefaults")
            from.availabilityDefaultsOpt.value.forEach { availabilityDefaultsOpt.set(string: $0) }
        }
        if from.ignoreAvailabilityAttrOpt.configured && !ignoreAvailabilityAttrOpt.configured {
            logDebug("Gather: \(debug) ignoreAvailabilityAttr")
            ignoreAvailabilityAttrOpt.set(bool: from.ignoreAvailabilityAttrOpt.value)
        }
        // objcdirect: don't cascade if buildtool [mutually exclusive]
        if from.objcDirectOpt.configured && !objcDirectOpt.configured && !buildToolOpt.configured {
            logDebug("Gather: \(debug) objCDirect")
            objcDirectOpt.set(bool: from.objcDirectOpt.value)
        }
        // objcheaderfile: don't cascade if build tool [not implemented]
        if from.objcHeaderFileOpt.configured && !objcHeaderFileOpt.configured && !buildToolOpt.configured {
            logDebug("Gather: \(debug) objCHeaderFile")
            objcHeaderFileOpt.set(string: from.objcHeaderFileOpt.configStringValue!, path: from.objcHeaderFileOpt.value!)
        }
        // objcincludepaths: always cascade
        if from.objcIncludePathsOpt.configured && !objcIncludePathsOpt.configured {
            logDebug("Gather: \(debug) objcIncludePaths")
            from.objcIncludePathsOpt.value.forEach { objcIncludePathsOpt.set(string: $0.path, path: $0) }
        }
        // objcsdk: always cascade
        if from.objcSdkOpt.configured && !objcSdkOpt.configured {
            logDebug("Gather: \(debug) objcSdk")
            try objcSdkOpt.set(string: from.objcSdkOpt.value!.rawValue)
        }
    }

    /// Second pass of options-checking, of inter-option consistency after parent cascade
    func checkCascadedOptions() throws {
        // Rigorously police the objc options...
        if objcDirectOpt.configured && buildToolOpt.configured {
            throw OptionsError(.localized(.errObjcBuildTools))
        }

        if (objcDirectOpt.configured || objcIncludePathsOpt.configured || objcSdkOpt.configured) &&
            !objcHeaderFileOpt.configured {
            throw OptionsError(.localized(.errObjcNoHeader))
        }

        if objcHeaderFileOpt.configured && !buildToolOpt.configured && !objcDirectOpt.configured {
            logDebug("Gather: ObjcHeaderFile and no BuildTool.  Inferring ObjcDirect")
            objcDirectOpt.set(bool: true)
        }

        if objcDirectOpt.configured {
            #if !os(macOS)
            throw OptionsError(.localized(.errObjcLinux))
            #endif
        }

        if objcHeaderFileOpt.configured && buildToolOpt.configured {
            throw NotImplementedError("Objective-C with build-tool")
        }
    }

    /// Generate jobs from the options
    func makeJobs(moduleName: String?) -> [GatherJob] {
        let availability =
            Gather.Availability(defaults: availabilityDefaultsOpt.value,
                                ignoreAttr: ignoreAvailabilityAttrOpt.value)

        var jobs = [GatherJob]()

        // CLI Job

        if objcHeaderFileOpt.configured {
            precondition(objcDirectOpt.configured)
            precondition(moduleName != nil)
            #if os(macOS)
            jobs.append(.objcDirect(moduleName: moduleName!,
                                    headerFile: objcHeaderFileOpt.value!,
                                    includePaths: objcIncludePathsOpt.value,
                                    sdk: objcSdkOpt.value!,
                                    buildToolArgs: buildToolArgsOpt.value,
                                    availability: availability))
            #endif
        } else {
            jobs.append(.swift(moduleName: moduleName,
                               srcDir: srcDirOpt.value,
                               buildTool: buildToolOpt.value,
                               buildToolArgs: buildToolArgsOpt.value,
                               availability: availability))
        }

        return jobs
    }
}

extension Gather {
    /// SDK for Objective-C building
    enum Sdk: String, CaseIterable {
        case macosx
        case iphoneos
        case iphonesimulator
        case appletvos
        case appletvsimulator
        case watchos
        case watchsimulator
    }

    /// Build tool for Swift/etc building
    enum BuildTool: String, CaseIterable {
        case spm
        case xcodebuild
    }

    /// Collected availability options
    struct Availability: Equatable {
        let defaults: [String]
        let ignoreAttr: Bool

        init(defaults: [String] = [], ignoreAttr: Bool = false) {
            self.defaults = defaults
            self.ignoreAttr = ignoreAttr
        }
    }
}
