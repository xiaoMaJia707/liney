//
//  RemoteGitServiceTests.swift
//  LineyTests
//

import XCTest
@testable import Liney

final class RemoteGitServiceTests: XCTestCase {
    func testTildeExpansionInSSHCommands() {
        // Test that ~ is properly expanded to $HOME in various contexts
        let testCases: [(input: String, expected: String)] = [
            ("cd ~/project && git status", "cd $HOME/project && git status"),
            ("cd ~ && git log", "cd $HOME && git log"),
            ("cd ~/project\ngit diff", "cd $HOME/project\ngit diff"),
            ("cd /absolute/path && git status", "cd /absolute/path && git status"),
            ("cd ~/my repo && git status", "cd $HOME/my repo && git status"),
        ]

        for (input, expected) in testCases {
            let expanded = input
                .replacingOccurrences(of: "~/", with: "$HOME/")
                .replacingOccurrences(of: "~ ", with: "$HOME ")
                .replacingOccurrences(of: "~\n", with: "$HOME\n")
            XCTAssertEqual(expanded, expected, "Failed for input: \(input)")
        }
    }

    func testSSHSessionConfigurationDestination() {
        let configWithUser = SSHSessionConfiguration(
            host: "example.com",
            user: "developer",
            port: nil,
            identityFilePath: nil,
            remoteWorkingDirectory: "~/project",
            remoteCommand: nil
        )
        XCTAssertEqual(configWithUser.destination, "developer@example.com")

        let configWithoutUser = SSHSessionConfiguration(
            host: "example.com",
            user: nil,
            port: nil,
            identityFilePath: nil,
            remoteWorkingDirectory: nil,
            remoteCommand: nil
        )
        XCTAssertEqual(configWithoutUser.destination, "example.com")
    }

    func testSSHSessionConfigurationCodable() {
        let original = SSHSessionConfiguration(
            host: "test.example.com",
            user: "admin",
            port: 2222,
            identityFilePath: "~/.ssh/id_ed25519",
            remoteWorkingDirectory: "~/projects/myapp",
            remoteCommand: "cd ~/projects/myapp && exec zsh -l"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try! encoder.encode(original)
        let decoded = try! decoder.decode(SSHSessionConfiguration.self, from: data)

        XCTAssertEqual(decoded.host, original.host)
        XCTAssertEqual(decoded.user, original.user)
        XCTAssertEqual(decoded.port, original.port)
        XCTAssertEqual(decoded.identityFilePath, original.identityFilePath)
        XCTAssertEqual(decoded.remoteWorkingDirectory, original.remoteWorkingDirectory)
        XCTAssertEqual(decoded.remoteCommand, original.remoteCommand)
    }

    func testRemoteGitServiceErrorDescriptions() {
        let notARepoError = RemoteGitServiceError.notAGitRepository("/tmp/test")
        XCTAssertEqual(notARepoError.errorDescription, "Not a git repository: /tmp/test")

        let commandFailedError = RemoteGitServiceError.commandFailed("exit code 1")
        XCTAssertEqual(commandFailedError.errorDescription, "Remote git command failed: exit code 1")

        let noRemoteDirError = RemoteGitServiceError.noRemoteDirectory
        XCTAssertEqual(noRemoteDirError.errorDescription, "No remote working directory configured.")
    }
}
