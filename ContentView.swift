import SwiftUI
import SwiftData
import Combine // Added for Timer.publish

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Transaction.symbol, order: .forward)]) private var transactions: [Transaction]
    @Query private var alerts: [PriceAlert]
    
    @State private var prices: [String: Double] = [:]
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var errorMessage: String?
    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
//    let testTimer = Timer.publish(every: 10, on: .main, in: .common).autoconnect() // Test timer (10 sec)
//    @State private var isTestTimerEnabled = false // Toggle for test timer
    
    private let alertManager: PriceAlertManager

    init() {
        self.alertManager = PriceAlertManager(modelContext: ModelContext(try! ModelContainer(for: Transaction.self, PriceAlert.self)))
    }
    
    private var groupedTransactions: [(symbol: String, totalAmount: Double, totalInvested: Double, coinId: String)] {
        var grouped: [String: (totalAmount: Double, totalInvested: Double, coinId: String)] = [:]
        for tx in transactions {
            let symbol = tx.symbol
            let amount = tx.amount
            let invested = tx.amountUSD
            let coinId = tx.coinId
            if var existing = grouped[symbol] {
                existing.totalAmount += amount
                existing.totalInvested += invested
                grouped[symbol] = existing
            } else {
                grouped[symbol] = (totalAmount: amount, totalInvested: invested, coinId: coinId)
            }
        }
        return grouped.map { (symbol: $0.key, totalAmount: $0.value.totalAmount, totalInvested: $0.value.totalInvested, coinId: $0.value.coinId) }
            .sorted { $0.symbol < $1.symbol }
    }
    
    private var portfolioSummary: (totalInvested: Double, totalValue: Double, totalProfit: Double) {
            let totalInvested = groupedTransactions.reduce(0.0) { $0 + $1.totalInvested }
            let totalValue = groupedTransactions.reduce(0.0) { sum, item in
                guard let price = prices[item.coinId] else { return sum }
                return sum + item.totalAmount * price
            }
            let totalProfit = totalValue - totalInvested
            return (totalInvested, totalValue, totalProfit)
        }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Assets"){
                    ForEach(groupedTransactions, id: \.symbol) { item in
                        NavigationLink(destination: TransactionDetailView(symbol: item.symbol, price:prices[item.coinId] ?? 0.0)) {
                            HStack {
                                HStack {
                                    Text("\(item.totalAmount, specifier: "%.4f")")
                                    Text(item.symbol)
                                        .font(.headline)
                                }
                                Spacer()
                                if let price = prices[item.coinId] {
                                    let value = item.totalAmount * price
                                    let profit = value - item.totalInvested
                                    VStack(alignment: .trailing) {
                                        Text("$\(item.totalInvested, specifier: "%.2f")")
                                        Text("$\(value, specifier: "%.2f")")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                    Spacer()
                                    Text("$\(profit, specifier: "%.2f") (\(profit > 0 ? "+" : "")\(profit / (item.totalInvested != 0 ? item.totalInvested : 1) * 100, specifier: "%.1f")%)")
                                        .foregroundColor(profit > 0 ? .green : .red)
                                        .font(.caption)
                                } else {
                                    Text("Fetching price... (ID: \(item.coinId))")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                Section("Alerts"){
                    ForEach(alerts) { alert in
                        NavigationLink(destination: TransactionDetailView(symbol: alert.symbol, price:prices[alert.coinId] ?? 0.0)){
                            HStack {
                                Text("\(alert.symbol) $\(alert.referencePrice, default: "%.2f") (\(alert.signedPercentage > 0 ? "+" : "")\(alert.signedPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                                Spacer()
                                Text(alert.createdAt.formatted(date: .numeric, time: .omitted))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Text("Total")
                        .font(.headline)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("$\(portfolioSummary.totalInvested, specifier: "%.2f")")
                        if portfolioSummary.totalValue > 0 {
                            let profit = portfolioSummary.totalProfit
                            Text("$\(portfolioSummary.totalValue, specifier: "%.2f")")
                                .foregroundColor(profit > 0 ? .green : .red)
                        }
                    }
                    .font(.caption)
                    Spacer()
                    if portfolioSummary.totalValue > 0 {
                        let profit = portfolioSummary.totalProfit
                        let percentage = portfolioSummary.totalInvested != 0 ? profit / portfolioSummary.totalInvested * 100 : 0
                        Text("$\(profit, specifier: "%.2f") (\(profit > 0 ? "+" : "")\(percentage, specifier: "%.1f")%)")
                            .foregroundColor(profit > 0 ? .green : .red)
                            .font(.caption)
                    } else {
                        Text("Fetching...")
                            .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .border(.gray.opacity(0.2), width: 1)
            }
            .overlay {
                if isLoading && prices.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("Assets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAdd = true }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { Task { await loadPrices() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
//                ToolbarItem(placement: .bottomBar) {
//                                Button(isTestTimerEnabled ? "Stop Test Timer" : "Start Test Timer") {
//                                    isTestTimerEnabled.toggle()
//                                }
//                            }
            }
            .sheet(isPresented: $showAdd) {
                AddTransactionView { symbol, name, amount, price, coinId in
                    let tx = Transaction(symbol: symbol, name: name, pricePerUnitUSD: price, amount: amount, coinId: coinId)
                    context.insert(tx)
                    try? context.save()
                    Task { await loadPrices() }
                }
            }
            .task {
                await preloadTopPrices()
                await loadPrices()
                await alertManager.requestNotificationPermission()
            }
            .onReceive(timer) { _ in
                Task { await loadPrices() }
            }
//            .onReceive(testTimer) { _ in
//                        if isTestTimerEnabled {
//                            Task {
//                                prices["bitcoin"] = 30000.0 // Simulate -50% for BTC
//                                print("Test timer triggered: Set bitcoin price to 30000.0")
//                                await alertManager.checkPriceAlerts(prices: prices)
//                            }
//                        }
//                    }
//            .refreshable { await loadPrices() }
//            .alert(item: $errorMessage) { message in
//                Alert(title: Text("Ошибка"), message: Text(message), dismissButton: .default(Text("OK")))
//            }
        }
    }
    
    private func preloadTopPrices() async {
        let topIds = ["bitcoin", "ethereum", "solana", "chainlink", "the-open-network", "sui", "ripple"]
        do {
            let topPrices = try await CoinGeckoService.shared.fetchPrices(for: topIds)
            prices.merge(topPrices) { $1 }
            print("Preloaded top prices: \(topPrices)")
        } catch {
            print("Preload error: \(error)")
        }
    }
    
    private func loadPrices() async {
        isLoading = true
        let uniqueIds = Set(groupedTransactions.map { $0.coinId }.filter { !$0.isEmpty })
        print("Requesting prices for IDs: \(uniqueIds.joined(separator: ","))")
        do {
            let newPrices = try await CoinGeckoService.shared.fetchPrices(for: Array(uniqueIds))
            prices.merge(newPrices) { $1 }
            // Simulate a price change for testing
            print("Loaded prices: \(prices)")
            await alertManager.checkPriceAlerts(prices: prices) // Use full prices dictionary
        } catch {
            errorMessage = "Не удалось загрузить цены: \(error.localizedDescription)"
            print("Price load error: \(error)")
        }
        isLoading = false
    }
}

extension String: Identifiable {
    public var id: String { self }
}

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, PriceAlert.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let mockTransactions = [
        Transaction(symbol: "BTC", name: "Bitcoin", pricePerUnitUSD: 50000, amount: 0.1, coinId: "bitcoin"),
        Transaction(symbol: "BTC", name: "Bitcoin", pricePerUnitUSD: 55000, amount: 0.05, coinId: "bitcoin"),
        Transaction(symbol: "ETH", name: "Ethereum", pricePerUnitUSD: 2000, amount: 1.0, coinId: "ethereum"),
        Transaction(symbol: "SOL", name: "Solana", pricePerUnitUSD: 500, amount: 10.0, coinId: "solana")
    ]
    
    for transaction in mockTransactions {
        container.mainContext.insert(transaction)
    }
    
    return ContentView()
        .modelContainer(container)
        .environment(\.locale, .init(identifier: "ru"))
}

private extension EnvironmentValues {
    @Entry var prices: [String: Double] = [:]
}
