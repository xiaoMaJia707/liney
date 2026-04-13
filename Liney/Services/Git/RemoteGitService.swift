//
//  RemoteGitService.swift
//  Liney
//

import Foundation

enum RemoteGitServiceError: LocalizedError {
    case notAGitRepository(String)
    case commandFailed(String)
    case noRemoteDirectory

    var errorDescription: String? {
        switch self {
        case .notAGitRepository(let path):
            return "Not a git repository: \(path)"
        case .commandFailed(let message):
            return "Remote git command failed: \(message)"
        case .noRemoteDirectory:
            return "No remote working directory configured."
        }
    }
}

actor RemoteGitService {
    private let runner = ShellCommandRunner()

    func repositoryRoot(
        configuration: SSHSessionConfiguration,
        remoteDirectory: String
    ) async throws -> String {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteDirectory)) && git rev-parse --show-toplevel"
        )
        guard result.exitCode == 0 else {
            throw RemoteGitServiceError.notAGitRepository(remoteDirectory)
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func listWorktrees(
        configuration: SSHSessionConfiguration,
        remoteRoot: String
    ) async throws -> [WorktreeModel] {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteRoot)) && git worktree list --porcelain"
        )
        guard result.exitCode == 0 else {
            throw RemoteGitServiceError.commandFailed(
                result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return GitRepositoryService.parseWorktreeList(result.stdout, rootPath: remoteRoot)
    }

    func currentBranch(
        configuration: SSHSessionConfiguration,
        remoteDirectory: String
    ) async throws -> String {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteDirectory)) && git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --abbrev-ref HEAD"
        )
        guard result.exitCode == 0 else {
            return "unknown"
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func diffNameStatus(
        configuration: SSHSessionConfiguration,
        remoteDirectory: String
    ) async throws -> String {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteDirectory)) && git diff --find-renames --find-copies --name-status HEAD -- 2>/dev/null"
        )
        return result.exitCode == 0 ? result.stdout : ""
    }

    func diffPatch(
        configuration: SSHSessionConfiguration,
        remoteDirectory: String,
        filePath: String
    ) async throws -> String {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteDirectory)) && git diff --find-renames --find-copies --no-color HEAD -- \(shellQuoted(filePath))"
        )
        return result.exitCode == 0 ? result.stdout : ""
    }

    func showFileAtRef(
        configuration: SSHSessionConfiguration,
        ref: String,
        filePath: String,
        remoteDirectory: String
    ) async throws -> String? {
        let result = try await runRemoteGit(
            configuration: configuration,
            command: "cd \(shellQuoted(remoteDirectory)) && git show \(ref):\(shellQuoted(filePath)) 2>/dev/null"
        )
        return result.exitCode == 0 ? result.stdout : nil
    }

    private func runRemoteGit(
        configuration: SSHSessionConfiguration,
        command: String
    ) async throws -> ShellCommandResult {
        var args: [String] = [
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
        ]
        if let port = configuration.port {
            args += ["-p", String(port)]
        }
        if let identity = configuration.identityFilePath, !identity.isEmpty {
            args += ["-i", identity]
        }
        args.append(configuration.destination)
        args.append(command)
        return try await runner.run(executable: "/usr/bin/ssh", arguments: args)
    }

    /// Quote a path for use in a remote shell command.
    /// Tilde paths are expanded using $HOME outside of quotes so the remote shell expands them.
    private func shellQuoted(_ value: String) -> String {
        if value.hasPrefix("~/") {
            let rest = String(value.dropFirst(2))
            return "\"$HOME\"/" + "'" + rest.replacingOccurrences(of: "'", with: "'\\''") + "'"
        }
        if value == "~" {
            return "\"$HOME\""
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
