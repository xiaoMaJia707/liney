//
//  HistoryWindowState.swift
//  Liney
//
//  Author: everettjf
//

import Combine
import Foundation

@MainActor
final class HistoryWindowState: ObservableObject {
    @Published var worktreePath: String?
    @Published var branchName: String = ""
    @Published var emptyStateMessage: String = "No commit history."

    // Commit list
    @Published var commits: [GitHistoryCommit] = []
    @Published var selectedCommitID: String?
    @Published var isLoadingCommits = false

    // Changed files for selected commit
    @Published var changedFiles: [DiffChangedFile] = []
    @Published var selectedFileID: String?
    @Published var isLoadingFiles = false

    // Diff document for selected file
    @Published var document: DiffFileDocument?
    @Published var isLoadingDocument = false

    @Published var loadErrorMessage: String?

    private let gitRepositoryService = GitRepositoryService()
    private var documentCache: [String: DiffFileDocument] = [:]
    private var commitListTask: Task<Void, Never>?
    private var fileListTask: Task<Void, Never>?
    private var documentTask: Task<Void, Never>?

    func load(worktreePath: String?, branchName: String, emptyStateMessage: String) {
        DiffDiagnostics.log("Loading history window state for branch \(branchName) at \(worktreePath ?? "<nil>")")
        self.worktreePath = worktreePath
        self.branchName = branchName
        self.emptyStateMessage = emptyStateMessage
        commits = []
        selectedCommitID = nil
        changedFiles = []
        selectedFileID = nil
        document = nil
        loadErrorMessage = nil
        documentCache = [:]
        commitListTask?.cancel()
        fileListTask?.cancel()
        documentTask?.cancel()
        guard let worktreePath else {
            isLoadingCommits = false
            isLoadingFiles = false
            isLoadingDocument = false
            return
        }
        commitListTask = Task { await reloadCommitList(for: worktreePath) }
    }

    func refresh() {
        guard let worktreePath else { return }
        DiffDiagnostics.log("Refreshing history commit list for \(worktreePath)")
        documentCache = [:]
        commitListTask?.cancel()
        fileListTask?.cancel()
        documentTask?.cancel()
        commitListTask = Task { await reloadCommitList(for: worktreePath) }
    }

    func updateCommitSelection(for id: String?) {
        fileListTask?.cancel()
        documentTask?.cancel()
        DiffDiagnostics.log("Selecting history commit id \(id ?? "<nil>")")

        guard let id,
              let worktreePath,
              let commit = commits.first(where: { $0.id == id }) else {
            changedFiles = []
            selectedFileID = nil
            document = nil
            isLoadingFiles = false
            isLoadingDocument = false
            return
        }

        changedFiles = []
        selectedFileID = nil
        document = nil
        documentCache = [:]
        isLoadingFiles = true
        isLoadingDocument = false
        fileListTask = Task { await reloadFileList(for: worktreePath, commit: commit) }
    }

    func updateDocumentSelection(for id: String?) {
        documentTask?.cancel()
        DiffDiagnostics.log("Selecting history file id \(id ?? "<nil>")")

        guard let id,
              let worktreePath,
              let selectedCommitID,
              let commit = commits.first(where: { $0.id == selectedCommitID }),
              let file = changedFiles.first(where: { $0.id == id }) else {
            document = nil
            isLoadingDocument = false
            return
        }

        let cacheKey = "\(commit.hash):\(id)"
        if let cached = documentCache[cacheKey] {
            DiffDiagnostics.log("Using cached history document for \(file.displayPath) at \(commit.shortHash)")
            document = cached
            isLoadingDocument = false
            return
        }

        document = nil
        isLoadingDocument = true
        documentTask = Task {
            let start = DiffDiagnostics.now()
            DiffDiagnostics.log("Starting history diff load for \(file.displayPath) at \(commit.shortHash)")
            do {
                let parentCommit = "\(commit.hash)~1"
                let loadedDocument = try await Task.detached(priority: .userInitiated) {
                    try await Self.loadHistoryDocument(
                        for: file,
                        worktreePath: worktreePath,
                        fromCommit: parentCommit,
                        toCommit: commit.hash
                    )
                }.value
                guard !Task.isCancelled else { return }
                documentCache[cacheKey] = loadedDocument
                document = loadedDocument
                isLoadingDocument = false
                DiffDiagnostics.log(
                    "Finished history diff load for \(file.displayPath) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))) [patchBytes=\(loadedDocument.unifiedPatch.utf8.count)]"
                )
            } catch {
                guard !Task.isCancelled else { return }
                DiffDiagnostics.error(
                    "History diff load failed for \(file.displayPath) after \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))): \(error.localizedDescription)"
                )
                document = DiffWindowState.makeDocument(
                    file: file,
                    unifiedPatch: error.localizedDescription.nonEmptyOrFallback("Unable to load diff.")
                )
                isLoadingDocument = false
            }
        }
    }

    // MARK: - Private

    private func reloadCommitList(for worktreePath: String) async {
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Loading commit history for \(worktreePath)")
        isLoadingCommits = true
        loadErrorMessage = nil

        do {
            let output = try await gitRepositoryService.commitLog(for: worktreePath)
            guard !Task.isCancelled else { return }
            let parsed = GitHistoryCommit.parseLog(output)
            commits = parsed
            isLoadingCommits = false
            DiffDiagnostics.log(
                "Loaded \(parsed.count) commits in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start)))"
            )

            if let first = parsed.first {
                selectedCommitID = first.id
                updateCommitSelection(for: first.id)
            }
        } catch {
            guard !Task.isCancelled else { return }
            DiffDiagnostics.error(
                "Loading commit history failed after \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start))): \(error.localizedDescription)"
            )
            commits = []
            isLoadingCommits = false
            loadErrorMessage = error.localizedDescription.nonEmptyOrFallback("Unable to load commit history.")
        }
    }

    private func reloadFileList(for worktreePath: String, commit: GitHistoryCommit) async {
        let start = DiffDiagnostics.now()
        DiffDiagnostics.log("Loading changed files for commit \(commit.shortHash)")
        isLoadingFiles = true

        do {
            let parentCommit = "\(commit.hash)~1"
            let output = try await gitRepositoryService.diffNameStatusBetweenCommits(
                for: worktreePath,
                fromCommit: parentCommit,
                toCommit: commit.hash
            )
            guard !Task.isCancelled else { return }

            let files = DiffChangedFile.parseNameStatus(output).sorted {
                $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending
            }

            changedFiles = files
            isLoadingFiles = false
            DiffDiagnostics.log(
                "Loaded \(files.count) changed files for commit \(commit.shortHash) in \(DiffDiagnostics.formatMilliseconds(DiffDiagnostics.elapsedMilliseconds(since: start)))"
            )

            if let first = files.first {
                selectedFileID = first.id
                updateDocumentSelection(for: first.id)
            }
        } catch {
            guard !Task.isCancelled else { return }
            DiffDiagnostics.error(
                "Loading changed files for commit \(commit.shortHash) failed: \(error.localizedDescription)"
            )
            changedFiles = []
            isLoadingFiles = false
            // For initial commits, the parent doesn't exist. Try diffing against empty tree.
            if error.localizedDescription.contains("unknown revision") {
                await reloadFileListForRootCommit(worktreePath: worktreePath, commit: commit)
            }
        }
    }

    private func reloadFileListForRootCommit(worktreePath: String, commit: GitHistoryCommit) async {
        DiffDiagnostics.log("Retrying file list for root commit \(commit.shortHash) using empty tree")
        isLoadingFiles = true
        do {
            let emptyTree = "4b825dc642cb6eb9a060e54bf899d69f7cb46208"
            let output = try await gitRepositoryService.diffNameStatusBetweenCommits(
                for: worktreePath,
                fromCommit: emptyTree,
                toCommit: commit.hash
            )
            guard !Task.isCancelled else { return }

            let files = DiffChangedFile.parseNameStatus(output).sorted {
                $0.displayPath.localizedStandardCompare($1.displayPath) == .orderedAscending
            }

            changedFiles = files
            isLoadingFiles = false

            if let first = files.first {
                selectedFileID = first.id
                updateDocumentSelection(for: first.id)
            }
        } catch {
            guard !Task.isCancelled else { return }
            DiffDiagnostics.error("Root commit file list also failed: \(error.localizedDescription)")
            changedFiles = []
            isLoadingFiles = false
        }
    }

    nonisolated private static func loadHistoryDocument(
        for file: DiffChangedFile,
        worktreePath: String,
        fromCommit: String,
        toCommit: String
    ) async throws -> DiffFileDocument {
        let gitRepositoryService = GitRepositoryService()
        let diffPath = file.newPath ?? file.oldPath ?? file.displayPath

        if file.status == .added {
            let newContents = try await gitRepositoryService.showFileAtCommit(diffPath, commit: toCommit, in: worktreePath) ?? ""
            return DiffWindowState.makeDocument(
                file: file,
                unifiedPatch: syntheticAddedPatch(path: diffPath, contents: newContents)
            )
        }

        if file.status == .deleted {
            let oldContents = try await gitRepositoryService.showFileAtCommit(file.oldPath ?? diffPath, commit: fromCommit, in: worktreePath) ?? ""
            return DiffWindowState.makeDocument(
                file: file,
                unifiedPatch: syntheticDeletedPatch(path: file.oldPath ?? diffPath, contents: oldContents)
            )
        }

        let patch = try await gitRepositoryService.diffPatchBetweenCommits(
            for: worktreePath,
            filePath: diffPath,
            fromCommit: fromCommit,
            toCommit: toCommit
        )

        if let patch = patch.nilIfEmpty {
            return DiffWindowState.makeDocument(file: file, unifiedPatch: patch)
        }

        return DiffWindowState.makeDocument(
            file: file,
            unifiedPatch: "No unified patch available for \(diffPath)."
        )
    }

    nonisolated private static func syntheticAddedPatch(path: String, contents: String) -> String {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        let body = lines.map { "+\($0)" }.joined(separator: "\n")
        let count = lines.count
        return """
        diff --git a/\(path) b/\(path)
        --- /dev/null
        +++ b/\(path)
        @@ -0,0 +1,\(count) @@
        \(body)
        """
    }

    nonisolated private static func syntheticDeletedPatch(path: String, contents: String) -> String {
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
        let body = lines.map { "-\($0)" }.joined(separator: "\n")
        let count = lines.count
        return """
        diff --git a/\(path) b/\(path)
        --- a/\(path)
        +++ /dev/null
        @@ -1,\(count) +0,0 @@
        \(body)
        """
    }
}
