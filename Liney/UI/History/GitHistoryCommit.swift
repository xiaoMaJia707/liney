//
//  GitHistoryCommit.swift
//  Liney
//
//  Author: everettjf
//

import Foundation

struct GitHistoryCommit: Identifiable, Hashable, Sendable {
    let hash: String
    let shortHash: String
    let authorName: String
    let authorDate: Date
    let subject: String

    var id: String { hash }

    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: authorDate, relativeTo: Date())
    }

    static func parseLog(_ output: String) -> [GitHistoryCommit] {
        let separator = "---COMMIT---"
        let fieldSeparator = "---FIELD---"
        return output
            .components(separatedBy: separator)
            .compactMap { block in
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let fields = trimmed.components(separatedBy: fieldSeparator)
                guard fields.count >= 5 else { return nil }
                let hash = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let shortHash = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let authorName = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let dateString = fields[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let subject = fields[4].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !hash.isEmpty else { return nil }
                let date = ISO8601DateFormatter().date(from: dateString) ?? Date.distantPast
                return GitHistoryCommit(
                    hash: hash,
                    shortHash: shortHash,
                    authorName: authorName,
                    authorDate: date,
                    subject: subject
                )
            }
    }
}
