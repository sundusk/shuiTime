//
//  AppNavigationState.swift
//  shuiTime
//
//  Created by Codex on 2026/03/21.
//

import Combine
import Foundation

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var selectedTimelineDate: Date = Date()
    @Published var focusedTimelineItemID: UUID?
    @Published var focusedInspirationItemID: UUID?
    @Published var presentedMomentItemID: UUID?
}
