//
//  SearchCoinView.swift
//  cryptobalanceV1
//
//  Created by Максим Ковалев on 8/22/25.
//

import SwiftUI

struct SearchCoinView: View {
    let onSelect: (Coin) -> Void
    @State private var searchText = ""
    @State private var coins: [Coin] = []
    @State private var currentLimit = 50  // Начальный лимит результатов
    
    private var filteredCoins: [Coin] {
        let lowerSearch = searchText.lowercased()
        return coins
            .filter {
                lowerSearch.isEmpty ||
                $0.symbol.lowercased().contains(lowerSearch) ||
                $0.name.lowercased().contains(lowerSearch)
            }
            .sorted { score(for: $0, search: lowerSearch) > score(for: $1, search: lowerSearch) }
    }
    
    private func score(for coin: Coin, search: String) -> Int {
        let lowerSymbol = coin.symbol.lowercased()
        let lowerName = coin.name.lowercased()
        let priorityIds = ["bitcoin", "ethereum", "solana", "chainlink", "the-open-network", "sui", "ripple"]
        let isPriority = priorityIds.contains(coin.id) ? 1000 : 0
        if lowerSymbol == search { return 200 + isPriority }
        if lowerSymbol.starts(with: search) { return 100 + isPriority }
        if lowerName == search { return 80 + isPriority }
        if lowerName.starts(with: search) { return 60 + isPriority }
        if lowerSymbol.contains(search) { return 40 + isPriority }
        if lowerName.contains(search) { return 20 + isPriority }
        return isPriority
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Поиск (ETH, Bitcoin...)", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                List {
                    ForEach(Array(filteredCoins.prefix(currentLimit))) { coin in
                        Button("\(coin.symbol.uppercased()) - \(coin.name)") {
                            onSelect(coin)
                        }
                    }
                    if currentLimit < filteredCoins.count {
                        Button("Ещё") {
                            currentLimit += 50
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
            .navigationTitle("Поиск монеты")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onSelect(Coin(id: "", symbol: "", name: "")) }  // Пустая монета для отмены
                }
            }
            .task { await loadCoins() }
        }
    }
    
    private func loadCoins() async {
        do {
            coins = try await CoinGeckoService.shared.fetchCoins()
            print("Loaded \(coins.count) coins in SearchCoinView")
        } catch {
            print("Failed to load coins in SearchCoinView: \(error)")
        }
    }
}
