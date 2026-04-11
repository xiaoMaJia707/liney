//
//  HistoryWindowContentView.swift
//  Liney
//
//  Author: everettjf
//

import SwiftUI
import YiTong

private enum HistoryDiffPresentationStyle: String {
    case split
    case unified
}

struct HistoryWindowContentView: View {
    @ObservedObject var state: HistoryWindowState
    @State private var commitSelection: String?
    @State private var fileSelection: String?
    @AppStorage("liney.history.viewStyle") private var diffStyleRaw = HistoryDiffPresentationStyle.split.rawValue

    private var diffStyle: HistoryDiffPresentationStyle {
        HistoryDiffPresentationStyle(rawValue: diffStyleRaw) ?? .split
    }

    init(state: HistoryWindowState) {
        self.state = state
        _commitSelection = State(initialValue: state.selectedCommitID)
        _fileSelection = State(initialValue: state.selectedFileID)
    }

    var body: some View {
        HSplitView {
            commitListPanel
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 420)
            fileListPanel
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 320)
            diffDetailPanel
                .frame(minWidth: 400)
        }
        .background(LineyTheme.appBackground)
        .onChange(of: commitSelection) { _, newValue in
            guard state.selectedCommitID != newValue else { return }
            state.selectedCommitID = newValue
            state.updateCommitSelection(for: newValue)
            fileSelection = nil
        }
        .onChange(of: state.selectedCommitID) { _, newValue in
            guard commitSelection != newValue else { return }
            commitSelection = newValue
        }
        .onChange(of: fileSelection) { _, newValue in
            guard state.selectedFileID != newValue else { return }
            state.selectedFileID = newValue
            state.updateDocumentSelection(for: newValue)
        }
        .onChange(of: state.selectedFileID) { _, newValue in
            guard fileSelection != newValue else { return }
            fileSelection = newValue
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Diff Style", selection: $diffStyleRaw) {
                    Image(systemName: "square.split.2x1")
                        .tag(HistoryDiffPresentationStyle.split.rawValue)
                    Image(systemName: "text.justify.left")
                        .tag(HistoryDiffPresentationStyle.unified.rawValue)
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .help("Diff Style")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
    }

    // MARK: - Commit List

    private var commitListPanel: some View {
        List(selection: $commitSelection) {
            ForEach(state.commits) { commit in
                HistoryCommitRow(commit: commit)
                    .tag(commit.id)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if state.isLoadingCommits && state.commits.isEmpty {
                ProgressView()
            } else if let loadErrorMessage = state.loadErrorMessage {
                ContentUnavailableView(
                    "Unable to Load History",
                    systemImage: "exclamationmark.triangle",
                    description: Text(loadErrorMessage)
                )
            } else if !state.isLoadingCommits && state.commits.isEmpty {
                ContentUnavailableView(
                    "No Commits",
                    systemImage: "clock",
                    description: Text(state.emptyStateMessage)
                )
            }
        }
    }

    // MARK: - File List

    private var fileListPanel: some View {
        List(selection: $fileSelection) {
            ForEach(state.changedFiles) { file in
                HistoryFileRow(file: file)
                    .tag(file.id)
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if state.selectedCommitID == nil && !state.isLoadingCommits {
                ContentUnavailableView(
                    "Select a Commit",
                    systemImage: "arrow.left.circle",
                    description: Text("Choose a commit to see its changes.")
                )
            } else if state.isLoadingFiles && state.changedFiles.isEmpty {
                ProgressView()
            } else if !state.isLoadingFiles && state.changedFiles.isEmpty && state.selectedCommitID != nil {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text("This commit has no file changes.")
                )
            }
        }
    }

    // MARK: - Diff Detail

    private var diffDetailPanel: some View {
        Group {
            if state.isLoadingDocument && state.document == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = state.document {
                VStack(spacing: 0) {
                    HistoryDiffDocumentHeader(file: document.file, commit: selectedCommit)
                    HistoryYiTongDocumentView(document: document, diffStyle: diffStyle)
                }
            } else if state.isLoadingFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.selectedCommitID == nil {
                ContentUnavailableView(
                    "Select a Commit",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Choose a commit from the history to view changes.")
                )
            } else if state.changedFiles.isEmpty {
                ContentUnavailableView(
                    "No Changes",
                    systemImage: "checkmark.circle",
                    description: Text("This commit has no file changes.")
                )
            } else {
                ContentUnavailableView(
                    "Select a File",
                    systemImage: "doc.text",
                    description: Text("Choose a changed file to view its diff.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LineyTheme.appBackground)
    }

    private var selectedCommit: GitHistoryCommit? {
        guard let id = state.selectedCommitID else { return nil }
        return state.commits.first { $0.id == id }
    }
}

// MARK: - Commit Row

private struct HistoryCommitRow: View {
    let commit: GitHistoryCommit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(commit.subject)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 6) {
                Text(commit.shortHash)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(LineyTheme.accent)

                Text(commit.authorName)
                    .font(.system(size: 11))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(commit.relativeDate)
                    .font(.system(size: 10))
                    .foregroundStyle(LineyTheme.mutedText)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - File Row

private struct HistoryFileRow: View {
    let file: DiffChangedFile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(file.statusSymbol)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(file.status.historyColor)
                    .frame(width: 14)

                Text(file.displayName)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if file.status == .renamed || file.status == .copied {
                    Text(file.status == .renamed ? "rename" : "copy")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(file.status.historyColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(file.status.historyColor.opacity(0.12), in: Capsule())
                }
            }

            if !file.directoryPath.isEmpty {
                Text(file.directoryPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            if let oldPath = file.oldPath, let newPath = file.newPath, oldPath != newPath {
                Text("\(oldPath) -> \(newPath)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(LineyTheme.mutedText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Diff Document Header

private struct HistoryDiffDocumentHeader: View {
    let file: DiffChangedFile
    let commit: GitHistoryCommit?

    var body: some View {
        HStack(spacing: 10) {
            Text(file.statusSymbol)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(file.status.historyColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(file.status.historyColor.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 3) {
                Text(file.displayName)
                    .font(.system(size: 14, weight: .semibold))
                HStack(spacing: 8) {
                    if !file.directoryPath.isEmpty {
                        Text(file.directoryPath)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(LineyTheme.mutedText)
                    }
                    if let commit {
                        Text(commit.shortHash)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(LineyTheme.accent)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LineyTheme.chromeBackground.opacity(0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(LineyTheme.border)
                .frame(height: 1)
        }
    }
}

// MARK: - YiTong Diff View

private struct HistoryYiTongDocumentView: View {
    let document: DiffFileDocument
    let diffStyle: HistoryDiffPresentationStyle

    var body: some View {
        DiffView(
            document: yiTongDocument,
            configuration: yiTongConfiguration
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LineyTheme.canvasBackground)
    }

    private var yiTongDocument: DiffDocument {
        DiffDocument(
            patch: document.unifiedPatch,
            title: document.file.displayPath
        )
    }

    private var yiTongConfiguration: DiffConfiguration {
        DiffConfiguration(
            appearance: .automatic,
            style: diffStyle == .split ? .split : .unified,
            indicators: .bars,
            showsLineNumbers: true,
            showsChangeBackgrounds: true,
            wrapsLines: false,
            showsFileHeaders: false,
            inlineChangeStyle: .wordAlt,
            allowsSelection: true
        )
    }
}

// MARK: - Color Extension

private extension DiffFileStatus {
    var historyColor: Color {
        switch self {
        case .modified:
            return LineyTheme.warning
        case .added:
            return LineyTheme.success
        case .deleted:
            return LineyTheme.danger
        case .renamed, .copied:
            return LineyTheme.accent
        case .unknown:
            return LineyTheme.mutedText
        }
    }
}
