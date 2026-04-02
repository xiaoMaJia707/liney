//
//  WorkspaceNotificationCenter.swift
//  Liney
//
//  Author: everettjf
//

import Foundation
import UserNotifications

@MainActor
final class WorkspaceNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = WorkspaceNotificationCenter()

    var onNotificationTapped: ((UUID, String?) -> Void)?

    private var hasRequestedAuthorization = false

    private override init() {
        super.init()
    }

    func deliver(title: String, body: String?, workspaceID: UUID? = nil, worktreePath: String? = nil) {
        let center = UNUserNotificationCenter.current()
        if !hasRequestedAuthorization {
            hasRequestedAuthorization = true
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }

        let content = UNMutableNotificationContent()
        content.title = title
        if let body, !body.isEmpty {
            content.body = body
        }
        content.sound = .default

        var userInfo: [String: String] = [:]
        if let workspaceID {
            userInfo["workspaceID"] = workspaceID.uuidString
        }
        if let worktreePath {
            userInfo["worktreePath"] = worktreePath
        }
        if !userInfo.isEmpty {
            content.userInfo = userInfo
        }

        let request = UNNotificationRequest(
            identifier: "com.liney.app.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let workspaceIDString = userInfo["workspaceID"] as? String
        let worktreePath = userInfo["worktreePath"] as? String

        if let workspaceIDString, let workspaceID = UUID(uuidString: workspaceIDString) {
            Task { @MainActor in
                self.onNotificationTapped?(workspaceID, worktreePath)
            }
        }

        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
