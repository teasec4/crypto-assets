import Foundation

struct Coin: Codable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
}

class CoinGeckoService {
    static let shared = CoinGeckoService()
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private let cacheKeyCoins = "cachedCoins"
    private let cacheKeyPrices = "cachedPrices"
    private let cacheExpiration: TimeInterval = 86400 // 24 часа для монет
    private let priceCacheExpiration: TimeInterval = 300 // 10 минут для цен
    
    private init() {}
    
    func fetchCoins() async throws -> [Coin] {
            if let cached = loadCachedCoins(), !isCacheExpired(key: cacheKeyCoins, expiration: cacheExpiration) {
                print("Using cached coins: \(cached.count) coins")
                return cached
            }
            
            let urlString = "\(baseURL)/coins/list"
            guard let url = URL(string: urlString) else {
                print("Invalid URL: \(urlString)")
                throw URLError(.badURL)
            }
            
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0  // Тайм-аут 5 сек
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid response for coins: not an HTTP response")
                    throw URLError(.badServerResponse)
                }
                print("HTTP Status for coins: \(httpResponse.statusCode)")
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("HTTP Error for coins: Status code \(httpResponse.statusCode)")
                    throw URLError(.badServerResponse)
                }
                let coins = try JSONDecoder().decode([Coin].self, from: data)
                print("Fetched \(coins.count) coins from API")
                cacheCoins(coins)
                return coins
            } catch {
                print("Error fetching coins: \(error.localizedDescription)")
                throw error
            }
        }
    
    func fetchPrices(for ids: [String]) async throws -> [String: Double] {
            if ids.isEmpty {
                print("No IDs provided for price fetch")
                return [:]
            }
            var allPrices: [String: Double] = [:]
            
            // Батчинг: разбиваем на группы по 50 id
            let batchSize = 50
            for batch in stride(from: 0, to: ids.count, by: batchSize) {
                let batchIds = Array(ids[batch..<min(batch + batchSize, ids.count)])
                if let cached = loadCachedPrices(), !isCacheExpired(key: cacheKeyPrices, expiration: priceCacheExpiration) {
                    let cachedBatch = cached.filter { batchIds.contains($0.key) }
                    if !cachedBatch.isEmpty {
                        allPrices.merge(cachedBatch) { $1 }
                        print("Using cached prices for batch: \(cachedBatch.keys.joined(separator: ","))")
                        continue
                    }
                }
                
                let idsString = batchIds.joined(separator: ",")
                let urlString = "\(baseURL)/simple/price?ids=\(idsString)&vs_currencies=usd"
                guard let url = URL(string: urlString) else {
                    print("Invalid price URL: \(urlString)")
                    throw URLError(.badURL)
                }
                
                var request = URLRequest(url: url)
                request.timeoutInterval = 5.0  // Тайм-аут 5 сек
                
                do {
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        print("Invalid response for prices: not an HTTP response")
                        throw URLError(.badServerResponse)
                    }
                    print("HTTP Status for prices batch: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 429 {
                        print("Rate limit exceeded (429) for batch. Consider adding API key or waiting.")
                        throw URLError(.dataNotAllowed)
                    }
                    guard (200...299).contains(httpResponse.statusCode) else {
                        print("HTTP Error for prices batch: Status code \(httpResponse.statusCode)")
                        if let errorString = String(data: data, encoding: .utf8) {
                            print("Response body: \(errorString)")
                        }
                        throw URLError(.badServerResponse)
                    }
                    let responseDict = try JSONDecoder().decode([String: [String: Double]].self, from: data)
                    let pricesBatch = responseDict.mapValues { $0["usd"] ?? 0.0 }
                    print("Fetched prices for batch: \(pricesBatch.keys.joined(separator: ","))")
                    allPrices.merge(pricesBatch) { $1 }
                    cachePrices(allPrices)  // Обновляем полный кэш
                } catch {
                    print("Error fetching prices batch: \(error.localizedDescription)")
                    throw error
                }
            }
            return allPrices
        }
    
    private func cacheCoins(_ coins: [Coin]) {
        do {
            let data = try JSONEncoder().encode(coins)
            UserDefaults.standard.set(data, forKey: cacheKeyCoins)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKeyCoins)_timestamp")
            print("Cached \(coins.count) coins")
        } catch {
            print("Error caching coins: \(error)")
        }
    }
    
    private func loadCachedCoins() -> [Coin]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKeyCoins) else {
            print("No cached coins found")
            return nil
        }
        do {
            let coins = try JSONDecoder().decode([Coin].self, from: data)
            return coins
        } catch {
            print("Error decoding cached coins: \(error)")
            return nil
        }
    }
    
    private func cachePrices(_ prices: [String: Double]) {
        do {
            let data = try JSONEncoder().encode(prices)
            UserDefaults.standard.set(data, forKey: cacheKeyPrices)
            UserDefaults.standard.set(Date(), forKey: "\(cacheKeyPrices)_timestamp")
            print("Cached prices for \(prices.count) coins")
        } catch {
            print("Error caching prices: \(error)")
        }
    }
    
    private func loadCachedPrices() -> [String: Double]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKeyPrices) else {
            print("No cached prices found")
            return nil
        }
        do {
            let prices = try JSONDecoder().decode([String: Double].self, from: data)
            return prices
        } catch {
            print("Error decoding cached prices: \(error)")
            return nil
        }
    }
    
    private func isCacheExpired(key: String, expiration: TimeInterval) -> Bool {
        guard let timestamp = UserDefaults.standard.object(forKey: "\(key)_timestamp") as? Date else {
            print("No cache timestamp for \(key)")
            return true
        }
        let expired = Date().timeIntervalSince(timestamp) > expiration
        print("Cache for \(key) \(expired ? "expired" : "valid")")
        return expired
    }
}
