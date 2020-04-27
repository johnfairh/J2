//
//  Sass.swift
//  J2Lib
//
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation
import J2Libsass

// Couldn't find an even slightly-convincing Swift wrapper for this.
// Future project?  Just a quick wrapper here for the basic function we want.
//
// Code samples are misleading over memory model, just bodging this through
// for now without much study.

enum Sass {
    struct Error: Swift.Error { // good grief need to rewrite J2Lib.Error
        let message: String

        init(_ message: String) {
            self.message = message
        }

        var description: String {
            message
        }

        var debugDescription: String {
            "[sass] \(description)"
        }
    }

    final class FileContext {
        let context: OpaquePointer

        init(file: URL) throws {
            guard let context = sass_make_file_context(file.path) else {
                throw Error("sass_make_file_context \(file.path) failed.")
            }
            self.context = context
        }

        func compile() throws -> String {
            let rc = sass_compile_file_context(context)
            guard rc == 0 else {
                var errMsg = "(??)"
                if let err = sass_context_get_error_message(context) {
                    errMsg = String(cString: err)
                }
                throw Error("sass_compile_file_context failed: \(rc) - \(errMsg)")
            }
            guard let output = sass_context_get_output_string(context) else {
                throw Error("sass_context_get_output_string failed.")
            }
            return String(cString: output)
        }

        deinit {
            sass_delete_file_context(context)
        }
    }

    final class Options {
        let options: OpaquePointer

        init(context: FileContext) throws {
            guard let options = sass_file_context_get_options(context.context) else {
                throw Error("sass_file_context_get_options failed.")
            }
            self.options = options
        }

        func set(inputPath: URL) {
            sass_option_set_input_path(options, inputPath.path)
        }

        func set(includeDirectories: [URL]) {
            let path = includeDirectories.map(\.path).joined(separator: ";")
            sass_option_set_include_path(options, path)
        }

        func set(outputStyle: Sass_Output_Style) {
            sass_option_set_output_style(options, outputStyle)
        }
    }

    static func render(scssFile: URL) throws -> String {
        let context = try FileContext(file: scssFile)
        let options = try Options(context: context)
        options.set(inputPath: scssFile)
        options.set(includeDirectories: [scssFile.deletingLastPathComponent()])
        options.set(outputStyle: SASS_STYLE_NESTED)
        return try context.compile()
    }
}
