import SwiftUI

struct AddPriceAlertView: View {
    @Environment(\.dismiss) private var dismiss
    let symbol: String
    let coinId: String
    let currentPrice: Double
    
    @State private var percentage: Double = 0.0
    
    var onSave: (String, String, Double, Double) -> Void
    
    private var targetPrice: Double {
        currentPrice * (1 + percentage / 100)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Coin") {
                    HStack {
                        Text(symbol)
                            .font(.headline)
                        Spacer()
                        Text("$\(currentPrice, specifier: "%.2f")")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Alert settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Change: ")
                            Spacer()
                            Text("\(percentage, specifier: "%.1f")%")
                                .foregroundStyle(percentage < 0 ? .red : percentage > 0 ? .green : .secondary)
                        }
                        
                        Slider(
                            value: $percentage,
                            in: -20...20,
                            step: 0.1
                        ) {
                            Text("Percentage change")
                        } minimumValueLabel: {
                            Text("-20%")
                                .foregroundColor(.red)
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("+20%")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                        .tint(percentage < 0 ? .red : percentage > 0 ? .green : .gray)
                        
                        Divider()
                        
                        HStack {
                            Text("Target price:")
                            Spacer()
                            Text("$\(targetPrice, specifier: "%.2f")")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(percentage < 0 ? .red : percentage > 0 ? .green : .primary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Set Price Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(symbol, coinId, currentPrice, percentage)
                        dismiss()
                    }
                    .disabled(percentage == 0)
                }
            }
        }
    }
}
