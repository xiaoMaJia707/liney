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
                            ForEach(Array(workspace.workflows.indices), id: \.self) { index in
                                workflowCard(workspaceModel: workspace, index: index)
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

    @ViewBuilder
    private func workflowCard(workspaceModel: WorkspaceModel, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + delete
            HStack {
                TextField(
                    localized("settings.workspace.workflow.name"),
                    text: Binding(
                        get: { workspaceModel.workflows[index].name },
                        set: { workspaceModel.settings.workflows[index].name = $0 }
                    )
                )
                .font(.system(size: 13, weight: .medium))
                Button(role: .destructive) {
                    workspaceModel.settings.workflows.remove(at: index)
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
                    workspaceModel.settings.workflows[index].commands.append(WorkspaceWorkflowBatchCommand())
                } label: {
                    Label(localized("settings.workspace.workflow.addBatchCommand"), systemImage: "plus")
                        .font(.system(size: 11))
                }
            }

            // Command cards
            let commandIndices = Array(workspaceModel.workflows[index].commands.indices)
            ForEach(commandIndices, id: \.self) { cmdIndex in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        TextField(
                            localized("settings.workspace.workflow.batchCommand.name"),
                            text: Binding(
                                get: { workspaceModel.workflows[index].commands[cmdIndex].name },
                                set: { workspaceModel.settings.workflows[index].commands[cmdIndex].name = $0 }
                            )
                        )
                        .frame(maxWidth: 160)

                        Picker("", selection: Binding(
                            get: { workspaceModel.workflows[index].commands[cmdIndex].splitAxis },
                            set: { workspaceModel.settings.workflows[index].commands[cmdIndex].splitAxis = $0 }
                        )) {
                            Text(localized("settings.workflow.batchCommand.splitRight")).tag(PaneSplitAxis.vertical)
                            Text(localized("settings.workflow.batchCommand.splitDown")).tag(PaneSplitAxis.horizontal)
                        }
                        .frame(maxWidth: 120)

                        Spacer()

                        Button(role: .destructive) {
                            workspaceModel.settings.workflows[index].commands.remove(at: cmdIndex)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }

                    TextField(
                        localized("settings.workspace.workflow.batchCommand.command"),
                        text: Binding(
                            get: { workspaceModel.workflows[index].commands[cmdIndex].command },
                            set: { workspaceModel.settings.workflows[index].commands[cmdIndex].command = $0 }
                        )
                    )
                    .font(.system(size: 12, design: .monospaced))
                }
                .padding(8)
                .background(LineyTheme.chromeBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if workspaceModel.workflows[index].commands.isEmpty {
                Text(localized("settings.workspace.workflow.batchCommandsHint"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            // Advanced options
            DisclosureGroup(localized("settings.workspace.workflow.advanced")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(localized("settings.workspace.workflow.localShell"), selection: Binding(
                        get: { workspaceModel.workflows[index].localSessionMode },
                        set: { workspaceModel.settings.workflows[index].localSessionMode = $0 }
                    )) {
                        ForEach(WorkspaceWorkflowLocalSessionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    Toggle(localized("settings.workspace.workflow.runSetupScript"), isOn: Binding(
                        get: { workspaceModel.workflows[index].runSetupScript },
                        set: { workspaceModel.settings.workflows[index].runSetupScript = $0 }
                    ))

                    Toggle(localized("settings.workspace.workflow.runWorkspaceScript"), isOn: Binding(
                        get: { workspaceModel.workflows[index].runWorkspaceScript },
                        set: { workspaceModel.settings.workflows[index].runWorkspaceScript = $0 }
                    ))

                    Picker(localized("settings.workspace.workflow.agentPreset"), selection: Binding(
                        get: { workspaceModel.workflows[index].agentPresetID },
                        set: { workspaceModel.settings.workflows[index].agentPresetID = $0 }
                    )) {
                        Text(localized("settings.workspace.workflow.noAgent")).tag(Optional<UUID>.none)
                        ForEach(store.appSettings.agentPresets) { preset in
                            Text(preset.name).tag(Optional(preset.id))
                        }
                    }

                    Picker(localized("settings.workspace.workflow.agentLaunch"), selection: Binding(
                        get: { workspaceModel.workflows[index].agentMode },
                        set: { workspaceModel.settings.workflows[index].agentMode = $0 }
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
