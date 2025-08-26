import SwiftUI

struct TransactionFormView: View {
    let coin: Coin
    var onSave: (String, Double, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var price: String = ""

    private var canSave: Bool {
        Double(amount) != nil && Double(price) != nil
    }

    private var previewValue: Double {
        (Double(amount) ?? 0) * (Double(price) ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
//                Section("Coin") {
//                    HStack {
//                        Text("Symbol")
//                        Spacer()
//                        Text(coin.symbol).foregroundStyle(.secondary)
//                    }
//                    HStack {
//                        Text("Name")
//                        Spacer()
//                        Text(coin.name).foregroundStyle(.secondary)
//                    }
//                }

                Section("Details") {
                    TextField("Name (optional)", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)

                    TextField("Price (USD)", text: $price)
                        .keyboardType(.decimalPad)
                }

                if canSave {
                    Section("Preview") {
                        HStack {
                            Text("Estimated cost")
                            Spacer()
                            Text("$\(previewValue, specifier: "%.2f")")
                                .font(.headline.monospacedDigit())
                        }
                    }
                }
            }
            .navigationTitle("Add \(coin.symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amt = Double(amount),
                              let pr  = Double(price) else { return }
                        onSave(name, amt, pr)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if name.isEmpty { name = coin.name }
            }
        }
    }
}
