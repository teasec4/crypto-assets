import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Transaction.symbol, order: .forward)]) private var transactions: [Transaction]
    @Query private var alerts: [PriceAlert]

    // persist
    @AppStorage("sections.showPrice")  private var showPricePersist  = true
    @AppStorage("sections.showAssets") private var showAssetsPersist = true
    @AppStorage("sections.showAlerts") private var showAlertsPersist = true
    // animate
    @State private var showPriceSection  = true
    @State private var showAssetsSection = true
    @State private var showAlertsSection = true

    @State private var prices: [String: Double] = [:]
    @State private var isLoading = false
    @State private var showAdd = false
    @State private var errorMessage: String?

    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()

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
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12, pinnedViews: []) {
                        // PRICE
                        VStack(spacing: 8) {
                            headerView(title: "Price", isOpen: $showPriceSection)
                            if showPriceSection {
                                LazyVGrid(
                                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                                    spacing: 8
                                ) {
                                    ForEach(groupedTransactions, id: \.symbol) { item in
                                        MiniCardView(symbol: item.symbol, price: prices[item.coinId])
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                                
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 16)

                        // ASSETS
                        VStack(spacing: 8) {
                            headerView(title: "Assets", isOpen: $showAssetsSection)
                            if showAssetsSection {
                                VStack(spacing: 8) {
                                    ForEach(groupedTransactions, id: \.symbol) { item in
                                        NavigationLink {
                                            TransactionDetailView(symbol: item.symbol, price: prices[item.coinId] ?? 0)
                                        } label: {
                                            AssetRow(symbol: item.symbol,
                                                     totalAmount: item.totalAmount,
                                                     totalInvested: item.totalInvested,
                                                     price: prices[item.coinId])
                                                
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // ALERTS
                        VStack(spacing: 8) {
                            headerView(title: "Alerts", isOpen: $showAlertsSection)
                            if showAlertsSection {
                                VStack(spacing: 8) {
                                    ForEach(alerts) { alert in
                                        NavigationLink {
                                            TransactionDetailView(symbol: alert.symbol, price: prices[alert.coinId] ?? 0.0)
                                        } label: {
                                            HStack {
                                                Text("\(alert.symbol) $\(alert.referencePrice, specifier: "%.2f") (\(alert.signedPercentage > 0 ? "+" : "")\(alert.signedPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                                                Spacer()
                                                Text(alert.createdAt.formatted(date: .numeric, time: .omitted))
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                            .background(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .fill(.ultraThinMaterial)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(.black.opacity(0.06), lineWidth: 1)
                                            )
                                            
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding()
                            }
                        }
                        
                        .padding(.horizontal, 16)

                        Spacer(minLength: 130) // место под нижнюю панель
                    }
                    .padding(.top, 8)
                }

                // Нижняя панель + FAB поверх
                VStack(spacing: 12) {
                    HStack {
                        Spacer()
                        Button {
                            showAdd = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.bold))
                                .padding(16)
                                .background(Circle().fill(.thinMaterial))
                                .overlay(Circle().stroke(.black.opacity(0.08), lineWidth: 1))
                                .shadow(radius: 6, y: 2)
                        }
                    }
                    .padding(.trailing, 16)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Total invested")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("$\(portfolioSummary.totalInvested, specifier: "%.2f")")
                                .font(.subheadline.monospacedDigit())
                        }
                        Divider().frame(height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Value")
                                .font(.caption2).foregroundStyle(.secondary)
                            Text("$\(portfolioSummary.totalValue, specifier: "%.2f")")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(portfolioSummary.totalProfit >= 0 ? .green : .red)
                        }
                        Spacer()
                        if portfolioSummary.totalValue > 0 {
                            let p = portfolioSummary.totalProfit
                            let percent = portfolioSummary.totalInvested == 0 ? 0 : p / portfolioSummary.totalInvested * 100
                            ProfitChip(profit: p, percent: percent)
                        } else {
                            Text("Fetching…").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(radius: 8, y: 2))
                    .padding(.horizontal, 12)

                    
                }
                .padding(.bottom, 8)
            }
            .navigationTitle("Assets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { Task { await loadPrices() } }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .overlay {
                if isLoading && prices.isEmpty { ProgressView() }
            }
        }
        // persist sync
        .onAppear {
            showPriceSection  = showPricePersist
            showAssetsSection = showAssetsPersist
            showAlertsSection = showAlertsPersist
        }
        .onChange(of: showPriceSection)  { showPricePersist  = $0 }
        .onChange(of: showAssetsSection) { showAssetsPersist = $0 }
        .onChange(of: showAlertsSection) { showAlertsPersist = $0 }

        .sheet(isPresented: $showAdd) {
            AddTransactionView { symbol, name, amount, price, coinId in
                let tx = Transaction(symbol: symbol, name: name, pricePerUnitUSD: price, amount: amount, coinId: coinId)
                context.insert(tx)
                try? context.save()
                Task { await loadPrices() }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
        .task {
            await preloadTopPrices()
            await loadPrices()
            await alertManager.requestNotificationPermission()
        }
        .onReceive(timer) { _ in
            Task { await loadPrices() }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // простой заголовок секции с коллапсом
    private func headerView(title: String, isOpen: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.up")
                .rotationEffect(.degrees(isOpen.wrappedValue ? 0 : 180))
                .animation(.easeInOut(duration: 0.2), value: isOpen.wrappedValue)
        }
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { isOpen.wrappedValue.toggle() } }
        .padding(.horizontal, 4)
        .padding(.top, 4)
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
            print("Loaded prices: \(prices)")
            await alertManager.checkPriceAlerts(prices: prices)
        } catch {
            errorMessage = "Не удалось загрузить цены: \(error.localizedDescription)"
            print("Price load error: \(error)")
        }
        isLoading = false
    }
}

extension String: Identifiable { public var id: String { self } }

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
