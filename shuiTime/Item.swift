//
//  Item.swift
//  shuiTime
//
//  Created by 强风吹拂 on 2025/12/9.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
