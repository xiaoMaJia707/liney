//
//  ShellCommandRunner.swift
//  Liney
//
//  Author: everettjf
//

import Foundation
import os

struct ShellCommandResult {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum ShellCommandError: LocalizedError {
    case executableNotFound(String)
    case failed(String)
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let executable):
            return "Executable not found: \(executable)"
        case .failed(let message):
            return message
        case .timedOut(let seconds):
            return "Command timed out after \(Int(seconds)) seconds"
        }
    }

    var isTimeout: Bool {
        if case .timedOut = self { return true }
        return false
    }
}

actor ShellCommandRunner {
    func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil
    ) async throws -> ShellCommandResult {
        guard FileManager.default.isExecutableFile(atPath: executable) || executable.contains("/") == false else {
            if AppLogger.isEnabled { AppLogger.shell.error("Executable not found: \(executable, privacy: .public)") }
            throw ShellCommandError.executableNotFound(executable)
        }

        let commandDescription = ([executable] + arguments).joined(separator: " ")
        if AppLogger.isVerbose { AppLogger.shell.debug("Running: \(commandDescription, privacy: .public) in \(currentDirectory ?? "(default)", privacy: .public)") }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let result: ShellCommandResult = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                continuation.resume(
                    returning: ShellCommandResult(
                        stdout: String(decoding: stdoutData, as: UTF8.self),
                        stderr: String(decoding: stderrData, as: UTF8.self),
                        exitCode: process.terminationStatus
                    )
                )
            }

            do {
                try process.run()
            } catch {
                if AppLogger.isEnabled { AppLogger.shell.error("Failed to launch process: \(error.localizedDescription, privacy: .public)") }
                continuation.resume(throwing: ShellCommandError.failed(error.localizedDescription))
            }
        }

        if result.exitCode != 0, AppLogger.isEnabled {
            AppLogger.shell.warning("Command exited with code \(result.exitCode): \(commandDescription, privacy: .public)")
            if !result.stderr.isEmpty {
                AppLogger.shell.warning("stderr: \(result.stderr.prefix(500), privacy: .public)")
            }
        }

        return result
    }

    func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval
    ) async throws -> ShellCommandResult {
        let commandDescription = ([executable] + arguments).joined(separator: " ")
        do {
            return try await withThrowingTaskGroup(of: ShellCommandResult.self) { group in
                group.addTask {
                    try await self.run(
                        executable: executable,
                        arguments: arguments,
                        currentDirectory: currentDirectory,
                        environment: environment
                    )
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw ShellCommandError.timedOut(timeout)
                }
                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch let error as ShellCommandError where error.isTimeout {
            if AppLogger.isEnabled { AppLogger.shell.error("Command timed out after \(Int(timeout))s: \(commandDescription, privacy: .public)") }
            throw error
        }
    }
}
