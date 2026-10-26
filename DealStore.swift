import Foundation
import SwiftUI

@MainActor
final class DealStore: ObservableObject {
    @AppStorage("bestBuyAPIKey") var apiKey = ""
    @AppStorage("walmartSearchKey") var walmartSearchKey = ""
    @AppStorage("authorizedTradeInFeedURL") var authorizedTradeInFeedURL = ""
    @AppStorage("authorizedTradeInFeedKey") var authorizedTradeInFeedKey = ""
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

        var errors: [String] = []
        var fetchedListings: [RetailListing] = []
        var refreshedQuotes: [TradeInQuote] = []

        let listingProviders: [ListingProvider] = [
            BestBuyProvider(apiKey: apiKey),
            WalmartSearchProvider(apiKey: walmartSearchKey)
        ].filter(\.isConfigured)

        let quoteProvider = AuthorizedTradeInFeedProvider(
            endpoint: authorizedTradeInFeedURL,
            apiKey: authorizedTradeInFeedKey
        )

        guard !listingProviders.isEmpty || quoteProvider.isConfigured else {
            errorMessage = ProviderError.missingAPIKey.localizedDescription
            return
        }

        let identifiers = Set(quotes.map(\.normalizedIdentifier))
        for provider in listingProviders {
            for identifier in identifiers {
                do { fetchedListings += try await provider.listings(for: identifier) }
                catch { errors.append("\(provider.name): \(error.localizedDescription)") }
            }
        }

        if quoteProvider.isConfigured {
            for identifier in identifiers {
                do { refreshedQuotes += try await quoteProvider.quotes(for: identifier) }
                catch { errors.append("Trade-in feed: \(error.localizedDescription)") }
            }
        }

        listings = fetchedListings
        if quoteProvider.isConfigured {
            let refreshedKeys = Set(refreshedQuotes.map {
                "\($0.normalizedIdentifier)|\($0.payoutType.rawValue)"
            })
            let manualQuotes = quotes.filter { quote in
                guard !quote.source.hasPrefix("Authorized feed:") else { return false }
                let key = "\(quote.normalizedIdentifier)|\(quote.payoutType.rawValue)"
                return !refreshedKeys.contains(key)
            }
            let markedQuotes = refreshedQuotes.map { quote in
                var quote = quote
                quote.source = "Authorized feed: \(quote.source)"
                return quote
            }
            quotes = manualQuotes + markedQuotes
            persist()
        }
        lastRefresh = Date()
        errorMessage = errors.isEmpty ? nil : Array(Set(errors)).sorted().joined(separator: "\n")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(quotes) {
            UserDefaults.standard.set(data, forKey: quotesKey)
        }
    }
}
