//
//  Item.swift
//  Formation Flight
//
//  Created by Jack Ellis on 12/15/23.
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
