import SwiftUI
import SwiftData

struct TransactionDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var transactions: [Transaction]
    @State private var showAdd = false
    let symbol: String
    
    init(symbol: String) {
        self.symbol = symbol
        _transactions = Query(
            filter: #Predicate<Transaction> { $0.symbol == symbol },
            sort: [SortDescriptor(\.date, order: .reverse)]
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
                    try? context.save()
                }
            }
        }
        .navigationTitle(symbol)
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
                try? context.save()
            }
        }
    }
}
