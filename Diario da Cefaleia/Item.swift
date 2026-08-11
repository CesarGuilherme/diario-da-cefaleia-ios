//
//  Item.swift
//  Diario da Cefaleia
//
//  Created by César Guilherme Lana Nonato on 11/08/26.
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
