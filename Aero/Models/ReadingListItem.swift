//
//  ReadingListItem.swift
//  Aero
//
//  Created by Aero on 2026-05-27.
//

import Foundation

/// Represents a web page saved for offline reading.
struct ReadingListItem: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let url: URL
    let excerpt: String
    let savedDate: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        excerpt: String = "",
        savedDate: Date = Date(),
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.excerpt = excerpt
        self.savedDate = savedDate
        self.isRead = isRead
    }
}
