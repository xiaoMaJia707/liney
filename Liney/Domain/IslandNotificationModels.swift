//
//  IslandNotificationModels.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

enum IslandItemStatus {
    case running
    case done
    case error
    case waitingForInput
}

struct IslandNotificationItem: Identifiable {
    let id: UUID
    let workspaceID: UUID
    let worktreePath: String?
    let title: String
    let agentName: String?
    let terminalTag: String?
    var status: IslandItemStatus
    let startedAt: Date
    var body: String?
    var prompt: IslandPrompt?
}

struct IslandPrompt {
    let question: String
    let options: [IslandPromptOption]
}

struct IslandPromptOption: Identifiable {
    let id: Int
    let label: String
    let responseText: String
}
