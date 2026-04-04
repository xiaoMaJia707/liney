//
//  WorkflowEditorSheet.swift
//  Liney
//
//  Author: everettjf
//

import SwiftUI

struct WorkflowEditorSheet: View {
    @EnvironmentObject private var store: WorkspaceStore
    @ObservedObject private var localization = LocalizationManager.shared

    let workspaceID: UUID

    @Environment(\.dismiss) private var dismiss

    private func localized(_ key: String) -> String {
        LocalizationManager.shared.string(key)
    }

    private var workspace: WorkspaceModel? {
        store.workspaces.first(where: { $0.id == workspaceID })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(localized("sheet.workflowEditor.title"))
                    .font(.system(size: 14, weight: .semibold))
                if let workspace {
                    Text("— \(workspace.name)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(localized("sheet.workflowEditor.addWorkflow")) {
                    workspace?.settings.workflows.append(
                        WorkspaceWorkflow(name: localized("defaults.workflow.name"))
                    )
                }
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let workspace {
                        if workspace.workflows.isEmpty {
                            Text(localized("settings.workspace.workflowsHint"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(workspace.workflows) { workflow in
                                workflowCard(workspaceModel: workspace, workflowID: workflow.id)
                            }
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button(localized("sheet.workflowEditor.done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 860, height: 620)
    }

    private func workflowIndex(in workspace: WorkspaceModel, id: UUID) -> Int? {
        workspace.workflows.firstIndex(where: { $0.id == id })
    }

    private func commandIndex(in workspace: WorkspaceModel, workflowID: UUID, commandID: UUID) -> (Int, Int)? {
        guard let wi = workflowIndex(in: workspace, id: workflowID),
              let ci = workspace.workflows[wi].commands.firstIndex(where: { $0.id == commandID }) else {
            return nil
        }
        return (wi, ci)
    }

    @ViewBuilder
    private func workflowCard(workspaceModel: WorkspaceModel, workflowID: UUID) -> some View {
        if let wi = workflowIndex(in: workspaceModel, id: workflowID) {
            let workflow = workspaceModel.workflows[wi]
            VStack(alignment: .leading, spacing: 10) {
                // Name + delete
                HStack {
                    TextField(
                        localized("settings.workspace.workflow.name"),
                        text: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.name ?? "" },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].name = $0 } }
                        )
                    )
                    .font(.system(size: 13, weight: .medium))
                    Button(role: .destructive) {
                        workspaceModel.settings.workflows.removeAll { $0.id == workflowID }
                    } label: {
                        Image(systemName: "trash")
                    }
                }

                // Batch commands header
                HStack {
                    Text(localized("settings.workspace.workflow.batchCommands"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        if wi < workspaceModel.settings.workflows.count {
                            workspaceModel.settings.workflows[wi].commands.append(WorkspaceWorkflowBatchCommand())
                        }
                    } label: {
                        Label(localized("settings.workspace.workflow.addBatchCommand"), systemImage: "plus")
                            .font(.system(size: 11))
                    }
                }

                // Command cards
                ForEach(workflow.commands) { cmd in
                    commandCard(workspaceModel: workspaceModel, workflowID: workflowID, commandID: cmd.id)
                }

                if workflow.commands.isEmpty {
                    Text(localized("settings.workspace.workflow.batchCommandsHint"))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                // Advanced options
                DisclosureGroup(localized("settings.workspace.workflow.advanced")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(localized("settings.workspace.workflow.localShell"), selection: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.localSessionMode ?? .reuseFocused },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].localSessionMode = $0 } }
                        )) {
                            ForEach(WorkspaceWorkflowLocalSessionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }

                        Toggle(localized("settings.workspace.workflow.runSetupScript"), isOn: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.runSetupScript ?? false },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].runSetupScript = $0 } }
                        ))

                        Toggle(localized("settings.workspace.workflow.runWorkspaceScript"), isOn: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.runWorkspaceScript ?? false },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].runWorkspaceScript = $0 } }
                        ))

                        Picker(localized("settings.workspace.workflow.agentPreset"), selection: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.agentPresetID },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].agentPresetID = $0 } }
                        )) {
                            Text(localized("settings.workspace.workflow.noAgent")).tag(Optional<UUID>.none)
                            ForEach(store.appSettings.agentPresets) { preset in
                                Text(preset.name).tag(Optional(preset.id))
                            }
                        }

                        Picker(localized("settings.workspace.workflow.agentLaunch"), selection: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.agentMode ?? .none },
                            set: { if wi < workspaceModel.settings.workflows.count { workspaceModel.settings.workflows[wi].agentMode = $0 } }
                        )) {
                            ForEach(WorkspaceWorkflowAgentMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(LineyTheme.subtleFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @ViewBuilder
    private func commandCard(workspaceModel: WorkspaceModel, workflowID: UUID, commandID: UUID) -> some View {
        if let (wi, ci) = commandIndex(in: workspaceModel, workflowID: workflowID, commandID: commandID) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    TextField(
                        localized("settings.workspace.workflow.batchCommand.name"),
                        text: Binding(
                            get: { workspaceModel.workflows[safe: wi]?.commands[safe: ci]?.name ?? "" },
                            set: {
                                if wi < workspaceModel.settings.workflows.count,
                                   ci < workspaceModel.settings.workflows[wi].commands.count {
                                    workspaceModel.settings.workflows[wi].commands[ci].name = $0
                                }
                            }
                        )
                    )
                    .frame(maxWidth: 160)

                    Picker("", selection: Binding(
                        get: { workspaceModel.workflows[safe: wi]?.commands[safe: ci]?.splitAxis ?? .vertical },
                        set: {
                            if wi < workspaceModel.settings.workflows.count,
                               ci < workspaceModel.settings.workflows[wi].commands.count {
                                workspaceModel.settings.workflows[wi].commands[ci].splitAxis = $0
                            }
                        }
                    )) {
                        Text(localized("settings.workflow.batchCommand.splitRight")).tag(PaneSplitAxis.vertical)
                        Text(localized("settings.workflow.batchCommand.splitDown")).tag(PaneSplitAxis.horizontal)
                    }
                    .frame(maxWidth: 120)

                    Spacer()

                    Button(role: .destructive) {
                        if wi < workspaceModel.settings.workflows.count {
                            workspaceModel.settings.workflows[wi].commands.removeAll { $0.id == commandID }
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                }

                TextField(
                    localized("settings.workspace.workflow.batchCommand.command"),
                    text: Binding(
                        get: { workspaceModel.workflows[safe: wi]?.commands[safe: ci]?.command ?? "" },
                        set: {
                            if wi < workspaceModel.settings.workflows.count,
                               ci < workspaceModel.settings.workflows[wi].commands.count {
                                workspaceModel.settings.workflows[wi].commands[ci].command = $0
                            }
                        }
                    )
                )
                .font(.system(size: 12, design: .monospaced))
            }
            .padding(8)
            .background(LineyTheme.chromeBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
