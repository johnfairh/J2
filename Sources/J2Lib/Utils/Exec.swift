//
//  Exec.swift
//  TMLMisc -> SourceKittenFramework -> J2Lib
//
//  Copyright © 2019 SourceKitten. All rights reserved.
//  Copyright 2020 J2 Authors
//  Licensed under MIT (https://github.com/johnfairh/J2/blob/master/LICENSE)
//

import Foundation

/// Namespace for utilities to execute a child process.
enum Exec {
    /// How to handle stderr output from the child process.
    enum Stderr {
        /// Treat stderr same as parent process.
        case inherit
        /// Send stderr to /dev/null.
        case discard
        /// Merge stderr with stdout.
        case merge
    }

    /// The result of running the child process.
    struct Results {
        /// The command that was run
        let command: String
        /// Its arguments
        let arguments: [String]
        /// The process's exit status.
        let terminationStatus: Int32
        /// The data from stdout and optionally stderr.
        let data: Data
        /// The `data` reinterpreted as a string with whitespace trimmed; `nil` for the empty string.
        var string: String? {
            let encoded = String(data: data, encoding: .utf8) ?? ""
            let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        /// The `data` reinterpreted as a string but intercepted to `nil` if the command actually failed
        var successString: String? {
            guard terminationStatus == 0 else {
                return nil
            }
            return string
        }
        /// Some text explaining a failure
        var failureReport: String {
            var report = """
            Command failed: \(command)
            Arguments: \(arguments)
            Exit status: \(terminationStatus)
            """
            if let output = string {
                report += ", output:\n\(output)"
            }
            return report
        }
    }

    /**
    Run a command with arguments and return its output and exit status.

    - parameter command: Absolute path of the command to run.
    - parameter arguments: Arguments to pass to the command.
    - parameter currentDirectory: Current directory for the command.  By default
                                  the parent process's current directory.
    - parameter stderr: What to do with stderr output from the command.  By default
                        whatever the parent process does.
    */
    static func run(_ command: String,
                    _ arguments: String...,
                    currentDirectory: String = FileManager.default.currentDirectoryPath,
                    stderr: Stderr = .inherit) -> Results {
        return run(command, arguments, currentDirectory: currentDirectory, stderr: stderr)
    }

    /**
     Run a command with arguments and return its output and exit status.

     - parameter command: Absolute path of the command to run.
     - parameter arguments: Arguments to pass to the command.
     - parameter currentDirectory: Current directory for the command.  By default
                                   the parent process's current directory.
     - parameter stderr: What to do with stderr output from the command.  By default
                         whatever the parent process does.
     */
     static func run(_ command: String,
                     _ arguments: [String] = [],
                     currentDirectory: String = FileManager.default.currentDirectoryPath,
                     stderr: Stderr = .inherit) -> Results {
        let process = Process()
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe

        switch stderr {
        case .discard:
            // FileHandle.nullDevice does not work here, as it consists of an invalid file descriptor,
            // causing process.launch() to abort with an EBADF.
            process.standardError = FileHandle(forWritingAtPath: "/dev/null")!
        case .merge:
            process.standardError = pipe
        case .inherit:
            break
        }

        do {
#if canImport(Darwin)
            if #available(macOS 10.13, *) {
                process.executableURL = URL(fileURLWithPath: command)
                process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
                try process.run()
            } else {
                process.launchPath = command
                process.currentDirectoryPath = currentDirectory
                process.launch()
            }
#elseif compiler(>=5)
            process.executableURL = URL(fileURLWithPath: command)
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
            try process.run()
#else
            process.launchPath = command
            process.currentDirectoryPath = currentDirectory
            process.launch()
#endif
        } catch {
            return Results(command: command, arguments: arguments, terminationStatus: -1, data: Data())
        }

        let file = pipe.fileHandleForReading
        let data = file.readDataToEndOfFile()
        process.waitUntilExit()
        return Results(command: command, arguments: arguments, terminationStatus: process.terminationStatus, data: data)
    }
}
