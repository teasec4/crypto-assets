//
//  PriceAlert.swift
//  cryptobalanceV1
//
//  Created by Максим Ковалев on 8/24/25.
//

import Foundation
import SwiftData

@Model
final class PriceAlert {
    var id: UUID
    var symbol: String
    var coinId: String
    var referencePrice: Double
    var signedPercentage: Double
    var createdAt: Date
    
    init(id: UUID = UUID(),
         symbol: String,
         coinId: String,
         referencePrice: Double,
         signedPercentage: Double,
         createdAt: Date = .now) {
        self.id = id
        self.symbol = symbol
        self.coinId = coinId
        self.referencePrice = referencePrice
        self.signedPercentage = signedPercentage
        self.createdAt = createdAt
    }
}
