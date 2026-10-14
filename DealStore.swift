import Foundation
import SwiftUI

@MainActor
final class DealStore: ObservableObject {
    @AppStorage("bestBuyAPIKey") var apiKey = ""
    @AppStorage("walmartSearchKey") var walmartSearchKey = ""
    @AppStorage("taxPercent") var taxPercent = 7.0

    @Published private(set) var quotes: [TradeInQuote] = []
    @Published private(set) var listings: [RetailListing] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefresh: Date?
    @Published var errorMessage: String?

    private let quotesKey = "tradeInQuotes"

    init() {
        if let data = UserDefaults.standard.data(forKey: quotesKey),
           let saved = try? JSONDecoder().decode([TradeInQuote].self, from: data) {
            quotes = saved
        }
    }

    var taxRate: Decimal { Decimal(taxPercent) / 100 }

    var deals: [Deal] {
        quotes.flatMap { quote in
            listings.filter { $0.matches(quote) }
                .map { Deal(listing: $0, quote: quote, taxRate: taxRate, extraCosts: 0) }
        }
    }

    var rankedDeals: [Deal] { deals.sorted { $0.roiPercent > $1.roiPercent } }
    var topDeals: [Deal] { Deal.topByROI(deals) }

    func add(_ quote: TradeInQuote) {
        quotes.append(quote)
        persist()
    }

    func delete(at offsets: IndexSet) {
        quotes.remove(atOffsets: offsets)
        persist()
    }

    func refresh() async {
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }
        let providers: [ListingProvider] = [
            BestBuyProvider(apiKey: apiKey),
            WalmartSearchProvider(apiKey: walmartSearchKey)
        ].filter(\.isConfigured)
        guard !providers.isEmpty else {
            errorMessage = ProviderError.missingAPIKey.localizedDescription
            return
        }
        var fetched: [RetailListing] = []
        var errors: [String] = []
        for provider in providers {
            for identifier in Set(quotes.map(\.normalizedIdentifier)) {
                do { fetched += try await provider.listings(for: identifier) }
                catch { errors.append("\(provider.name): \(error.localizedDescription)") }
            }
        }
        listings = fetched
        lastRefresh = Date()
        errorMessage = errors.isEmpty ? nil : Array(Set(errors)).sorted().joined(separator: "\n")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(quotes) {
            UserDefaults.standard.set(data, forKey: quotesKey)
        }
    }
}
