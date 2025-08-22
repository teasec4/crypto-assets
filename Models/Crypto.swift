import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var symbol: String
    var name: String
    var pricePerUnitUSD: Double
    var date: Date
    var amount: Double
    var coinId: String
    
    init(id: UUID = UUID(),
         symbol: String,
         name: String,
         pricePerUnitUSD: Double,
         date: Date = .now,
         amount: Double,
         coinId: String) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.pricePerUnitUSD = pricePerUnitUSD
        self.date = date
        self.amount = amount
        self.coinId = coinId
    }
    
    var amountUSD: Double {
        return amount * pricePerUnitUSD
    }
}
