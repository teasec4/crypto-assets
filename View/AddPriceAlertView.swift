//
//  AddPriceAlertView.swift
//  cryptobalanceV1
//
//  Created by Максим Ковалев on 8/24/25.
//

import SwiftUI

struct AddPriceAlertView: View {
    @Environment(\.dismiss) private var dismiss
    let symbol: String
    let coinId: String
    let currentPrice: Double
    @State private var percentage: Double = 0.0 // Default to 0%
    
    
    var onSave: (String, String, Double, Double) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Alert Details") {
                    Text("Coin: \(symbol)")
                    Text("Current Price: $\(currentPrice, default: "%.2f")")
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Percentage Change: \(percentage.formatted(.number.precision(.fractionLength(1))))%")
                            .foregroundColor(percentage < 0 ? .red : percentage > 0 ? .green : .primary)
                        Slider(
                            value: $percentage,
                            in: -20...20, // Range from -20% to +20%
                            step: 0.1,
                            label: { Text("") },
                            minimumValueLabel: { Text("-20%").foregroundColor(.red).font(.caption) },
                            maximumValueLabel: { Text("+20%").foregroundColor(.green).font(.caption) }
                        )
                        .tint(percentage < 0 ? .red : percentage > 0 ? .green : .gray)
                    }
                }
            }
            .navigationTitle("Set Price Alert")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(symbol, coinId, currentPrice, percentage) // Save signed percentage
                        dismiss()
                    }
                    .disabled(percentage == 0)
                }
            }
        }
    }
}
