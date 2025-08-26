import SwiftUI
import SwiftData
import Combine // Added for Timer.publish

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: [SortDescriptor(\Transaction.symbol, order: .forward)]) private var transactions: [Transaction]
    @Query private var alerts: [PriceAlert]
    
    // 1) Персистентные значения (UserDefaults)
    @AppStorage("sections.showPrice")  private var showPricePersist  = true
    @AppStorage("sections.showAssets") private var showAssetsPersist = true
    @AppStorage("sections.showAlerts") private var showAlertsPersist = true

    // 2) Локальные флаги для плавной анимации
    @State private var showPriceSection  = true
    @State private var showAssetsSection = true
    @State private var showAlertsSection = true
    
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
                Section {
                    if showPriceSection {
                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 8),
                                      GridItem(.flexible(), spacing: 8)],
                            spacing: 8
                        ) {
                            ForEach(groupedTransactions, id: \.symbol) { item in
                                MiniCardView(symbol: item.symbol, price: prices[item.coinId])
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Price")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up")
                            .rotationEffect(.degrees(showPriceSection ? 0 : 180))
                            .animation(.easeInOut(duration: 0.2), value: showPriceSection)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { showPriceSection.toggle() } }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Section {
                    if showAssetsSection {
                        ForEach(groupedTransactions, id: \.symbol) { item in
                            NavigationLink {
                                TransactionDetailView(symbol: item.symbol, price: prices[item.coinId] ?? 0)
                            } label: {
                                AssetRow(symbol: item.symbol,
                                         totalAmount: item.totalAmount,
                                         totalInvested: item.totalInvested,
                                         price: prices[item.coinId])
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Assets")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up")
                            .rotationEffect(.degrees(showAssetsSection ? 0 : 180))
                            .animation(.easeInOut(duration: 0.2), value: showAssetsSection)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { showAssetsSection.toggle() } }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
                Section {
                    if showAlertsSection {
                        ForEach(alerts) { alert in
                            NavigationLink(destination: TransactionDetailView(symbol: alert.symbol, price: prices[alert.coinId] ?? 0.0)) {
                                HStack {
                                    Text("\(alert.symbol) $\(alert.referencePrice, specifier: "%.2f") (\(alert.signedPercentage > 0 ? "+" : "")\(alert.signedPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                                    Spacer()
                                    Text(alert.createdAt.formatted(date: .numeric, time: .omitted))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Alerts")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.up")
                            .rotationEffect(.degrees(showAlertsSection ? 0 : 180))
                            .animation(.easeInOut(duration: 0.2), value: showAlertsSection)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation { showAlertsSection.toggle() } }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
            }
            // где NavigationStack { List { ... } }
            .listStyle(.insetGrouped)
            .listRowSeparator(.hidden)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .padding(.vertical, 4)
            )
            
            .safeAreaInset(edge: .bottom) {
                // один общий inset, внутри — и панель, и FAB
                ZStack(alignment: .bottomTrailing) {
                    // твоя панель суммарных значений
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
                            Text("Fetching…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 8, y: 2)
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)

                    // FAB внутри того же inset — уже не перекрывает панель
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
                    .padding(.trailing, 16)
                    .padding(.bottom, 75) // тонкая подстройка, чтобы висел над панелью
                }
            }
            .overlay {
                if isLoading && prices.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("Assets")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                                    Button(action: { Task { await loadPrices() } }) {
                                        Image(systemName: "arrow.clockwise")
                                    }
                                }
            }
        }
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
            .presentationDragIndicator(.hidden) // убрать индикатор свайпа
        }
        
        .task {
            await preloadTopPrices()
            await loadPrices()
            await alertManager.requestNotificationPermission()
        }
        .onReceive(timer) { _ in
            Task { await loadPrices() }
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
