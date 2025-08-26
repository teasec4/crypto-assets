import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]
    
    // выбор монеты
    @State private var selectedCoinId = ""
    @State private var selectedCoin: Coin? = nil
    @State private var showSearchSheet = false
    @State private var showForm = false
    
    // итоговый коллбэк наружу
    var onSave: (String, String, Double, Double, String) -> Void
    
    // популярные (фиксированный список)
    private let popularCoins: [Coin] = [
        Coin(id: "bitcoin",          symbol: "BTC", name: "Bitcoin"),
        Coin(id: "ethereum",         symbol: "ETH", name: "Ethereum"),
        Coin(id: "solana",           symbol: "SOL", name: "Solana"),
        Coin(id: "chainlink",        symbol: "LINK", name: "Chainlink"),
        Coin(id: "the-open-network", symbol: "TON", name: "The Open Network"),
        Coin(id: "sui",              symbol: "SUI", name: "Sui"),
        Coin(id: "ripple",           symbol: "XRP", name: "Ripple")
    ]
    
    // последние по транзакциям
    private var recentCoins: [Coin] {
        let recentSymbols = Array(Set(transactions.map { $0.symbol }))
        return recentSymbols.compactMap { sym in
            if let tx = transactions.first(where: { $0.symbol == sym }) {
                return Coin(id: tx.coinId, symbol: sym, name: tx.name)
            }
            return nil
        }
        .sorted { $0.symbol < $1.symbol }
    }
    
    // список для Picker: сначала recent, потом popular без дублей
    private var allCoinsForPicker: [Coin] {
        var seen = Set<String>()
        var out: [Coin] = []
        for c in recentCoins {
            if !seen.contains(c.id) { out.append(c); seen.insert(c.id) }
        }
        for c in popularCoins {
            if !seen.contains(c.id) { out.append(c); seen.insert(c.id) }
        }
        return out
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Coin") {
                    Picker("Select coin", selection: $selectedCoinId) {
                        Text("— select —").tag("")
                        ForEach(allCoinsForPicker, id: \.id) { coin in
                            Text("\(coin.symbol) — \(coin.name)").tag(coin.id)
                        }
                    }
                    Button {
                        showSearchSheet = true
                    } label: {
                        Label("Search coin…", systemImage: "magnifyingglass")
                    }
                }
                
                if let coin = selectedCoin {
                    Section("Selected") {
                        HStack {
                            Text("Symbol")
                            Spacer()
                            Text(coin.symbol).foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(coin.name).foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button {
                        showForm = true
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(selectedCoin == nil)
                }
            }
            .navigationTitle("New transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: selectedCoinId) { newValue in
                if let c = allCoinsForPicker.first(where: { $0.id == newValue }) {
                    selectedCoin = c
                } else {
                    selectedCoin = nil
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                // Используй свою реализацию SearchCoinView, она вернёт Coin
                SearchCoinView { selected in
                    if !selected.id.isEmpty {
                        selectedCoinId = selected.id
                        selectedCoin = selected
                    }
                    showSearchSheet = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden) // убрать индикатор свайпа
            }
            .sheet(isPresented: $showForm) {
                if let coin = selectedCoin {
                    TransactionFormView(
                        coin: coin,
                        onSave: { name, amount, price in
                            onSave(
                                coin.symbol.uppercased(),
                                name.isEmpty ? coin.name : name,
                                amount,
                                price,
                                coin.id
                            )
                            showForm = false
                            dismiss()
                        }
                    )
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.hidden) // убрать индикатор свайпа
                }
                    
            }
        }
    }
}
