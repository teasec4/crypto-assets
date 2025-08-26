import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @Query private var alerts: [PriceAlert]
    
//    @State private var showAdd = false
    @State private var showAlertForm = false
    
    let symbol: String
    let price: Double
    
    init(symbol: String, price: Double) {
        self.symbol = symbol
        self.price = price
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.symbol == symbol },
            sort: [SortDescriptor(\.date, order: .reverse)]
        )
        _alerts = Query(
            filter: #Predicate<PriceAlert> { $0.symbol == symbol },
            sort: [SortDescriptor(\.createdAt, order: .reverse)]
        )
    }
    
    var body: some View {
        List {
            // --- Transactions ---
            Section("Transactions") {
                ForEach(transactions) { tx in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(tx.amount, specifier: "%.4f") \(symbol)")
                                .font(.subheadline.weight(.semibold))
                            Text(tx.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(tx.amountUSD, specifier: "%.2f")")
                                .font(.subheadline.monospacedDigit())
                            Text("$\(tx.pricePerUnitUSD, specifier: "%.2f")")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { idx in
                    for i in idx { context.delete(transactions[i]) }
                    try? context.save()
                }
            }
            
            // --- Alerts ---
            Section("Price Alerts") {
                ForEach(alerts) { alert in
                    HStack {
                        Text("$\(alert.referencePrice, specifier: "%.2f") (\(alert.signedPercentage > 0 ? "+" : "")\(alert.signedPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                        Spacer()
                        Text(alert.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { idx in
                    for i in idx { context.delete(alerts[i]) }
                    try? context.save()
                }
                
                Button {
                    showAlertForm = true
                } label: {
                    Label("Add Price Alert", systemImage: "bell.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("\(symbol) $\(price, specifier: "%.2f")")
//        .toolbar {
//            ToolbarItem(placement: .topBarTrailing) {
//                Button {
//                    showAdd = true
//                } label: {
//                    Image(systemName: "plus")
//                }
//            }
//        }
//        .sheet(isPresented: $showAdd) {
//            AddTransactionView { _, name, amount, price, coinId in
//                let tx = Transaction(
//                    symbol: symbol,
//                    name: name,
//                    pricePerUnitUSD: price,
//                    amount: amount,
//                    coinId: coinId.isEmpty ? symbol.lowercased() : coinId
//                )
//                context.insert(tx)
//                try? context.save()
//            }
//            .presentationDetents([.medium])
//            .presentationDragIndicator(.hidden) // убрать индикатор свайпа
//        }
        .sheet(isPresented: $showAlertForm) {
            AddPriceAlertView(
                symbol: symbol,
                coinId: transactions.first?.coinId ?? symbol.lowercased(),
                currentPrice: price
            ) { symbol, coinId, referencePrice, percentage in
                let alert = PriceAlert(
                    symbol: symbol,
                    coinId: coinId,
                    referencePrice: referencePrice,
                    signedPercentage: percentage
                )
                context.insert(alert)
                try? context.save()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden) // убрать индикатор свайпа
        }
    }
}
