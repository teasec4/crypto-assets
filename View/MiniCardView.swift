//
//  MiniCardView.swift
//  cryptobalanceV1
//
//  Created by Максим Ковалев on 8/25/25.
//

import SwiftUI

struct MiniCardView: View {
    let symbol : String
    let price : Double
    var body: some View {
        HStack {
            Text(symbol)
                .font(.headline)
            Spacer()
            Text(String(format: "$%.2f", price))
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .foregroundStyle(.secondary)
        
    }
}

#Preview {
    MiniCardView(symbol: "BTC", price: 60000.0)
}
