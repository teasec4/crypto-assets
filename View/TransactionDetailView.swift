import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @Query private var alerts: [PriceAlert]
    @State private var showAdd = false
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
            Section("Transactions") {
                ForEach(transactions) { tx in
                    HStack {
                        Text("\(tx.amount, specifier: "%.4f")")
                            .font(.caption)
                        Text(symbol)
                            .font(.headline)
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("$\(tx.amountUSD, specifier: "%.2f")")
                            Text("$\(tx.pricePerUnitUSD, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                        Spacer()
                        Text(tx.date.formatted(date: .numeric, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(transactions[i]) }
                    do {
                        try context.save()
                        print("Deleted transaction and saved context")
                    } catch {
                        print("Failed to save context after deleting transaction: \(error)")
                    }
                }
            }
            Section("Set Price Alert") {
                ForEach(alerts) { alert in
                    HStack {
                        Text("$\(alert.referencePrice, default: "%.2f") (\(alert.signedPercentage > 0 ? "+" : "")\(alert.signedPercentage.formatted(.number.precision(.fractionLength(1))))%)")
                        Spacer()
                        Text(alert.createdAt.formatted(date: .numeric, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(alerts[i]) }
                    do {
                        try context.save()
                        print("Deleted price alert and saved context")
                    } catch {
                        print("Failed to save context after deleting price alert: \(error)")
                    }
                }
                Button("Add Price Alert") {
                    showAlertForm = true
                }
            }
        }
        .navigationTitle("\(symbol) $\(price, specifier: "%.2f")")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddTransactionView { _, name, amount, price, coinId in
                let tx = Transaction(
                    symbol: symbol,
                    name: name,
                    pricePerUnitUSD: price,
                    amount: amount,
                    coinId: coinId.isEmpty ? symbol.lowercased() : coinId
                )
                context.insert(tx)
                do {
                    try context.save()
                    print("Saved new transaction: \(symbol), amount: \(amount)")
                } catch {
                    print("Failed to save new transaction: \(error)")
                }
            }
        }
        .sheet(isPresented: $showAlertForm) {
            AddPriceAlertView(symbol: symbol, coinId: transactions.first?.coinId ?? symbol.lowercased(), currentPrice: price) { symbol, coinId, referencePrice, percentage in
                let alert = PriceAlert(
                    symbol: symbol,
                    coinId: coinId,
                    referencePrice: referencePrice,
                    signedPercentage: percentage
                )
                context.insert(alert)
                do {
                    try context.save()
                    print("Saved new price alert: \(symbol), percentage: \(percentage)")
                } catch {
                    print("Failed to save new price alert: \(error)")
                }
            }
        }
    }
}
