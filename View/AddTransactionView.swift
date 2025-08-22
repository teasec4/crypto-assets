import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]
    
    @State private var selectedCoinId = ""
    @State private var selectedCoin: Coin? = nil
    @State private var amount = ""
    @State private var price = ""
    @State private var name = ""
    @State private var showSearchSheet = false  // Для открытия Sheet с поиском
    
    private let popularCoins = [
        Coin(id: "bitcoin", symbol: "BTC", name: "Bitcoin"),
        Coin(id: "ethereum", symbol: "ETH", name: "Ethereum"),
        Coin(id: "solana", symbol: "SOL", name: "Solana"),
        Coin(id: "chainlink", symbol: "LINK", name: "Chainlink"),
        Coin(id: "the-open-network", symbol: "TON", name: "The Open Network"),
        Coin(id: "sui", symbol: "SUI", name: "Sui"),
        Coin(id: "ripple", symbol: "XRP", name: "Ripple")
    ]
    
    private var recentCoins: [Coin] {
        let recentSymbols = Array(Set(transactions.map { $0.symbol }))
        return recentSymbols.compactMap { sym in
            let tx = transactions.first { $0.symbol == sym }
            return tx != nil ? Coin(id: tx!.coinId, symbol: sym, name: tx!.name) : nil
        }.sorted { $0.symbol < $1.symbol }
    }
    
    var onSave: (String, String, Double, Double, String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Выберите монету") {
                    Picker("Монета", selection: $selectedCoinId) {
                        Text("Выберите монету").tag("")
                        ForEach(recentCoins) { coin in
                            Text("\(coin.symbol) - \(coin.name)").tag(coin.id)
                        }
                        ForEach(popularCoins) { coin in
                            Text("\(coin.symbol) - \(coin.name)").tag(coin.id)
                        }
                        Text("Другая").tag("other")
                    }
                }
                Section("Детали транзакции") {
                    TextField("Название", text: $name)
                    TextField("Количество", text: $amount).keyboardType(.decimalPad)
                    TextField("Цена за единицу ($)", text: $price).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Новая транзакция")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if let coin = selectedCoin ?? popularCoins.first(where: { $0.id == selectedCoinId }) ?? recentCoins.first(where: { $0.id == selectedCoinId }) {
                            if let amt = Double(amount), let pr = Double(price) {
                                onSave(coin.symbol.uppercased(), name.isEmpty ? coin.name : name, amt, pr, coin.id)
                                dismiss()
                            }
                        }
                    }
                    .disabled(selectedCoinId.isEmpty || amount.isEmpty || price.isEmpty)
                }
            }
            .onChange(of: selectedCoinId) {
                if selectedCoinId == "other" {
                    showSearchSheet = true
                } else if selectedCoinId != "" {
                    if let coin = popularCoins.first(where: { $0.id == selectedCoinId }) ?? recentCoins.first(where: { $0.id == selectedCoinId }) {
                        selectedCoin = coin
                        name = coin.name
                    }
                } else {
                    selectedCoin = nil
                    name = ""
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                SearchCoinView { selected in
                    selectedCoin = selected
                    name = selected.name
                    selectedCoinId = selected.id
                    showSearchSheet = false
                }
            }
        }
    }
}
