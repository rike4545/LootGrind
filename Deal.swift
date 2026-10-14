import Foundation

enum PayoutType: String, CaseIterable, Identifiable, Codable {
    case cash = "Cash"
    case storeCredit = "Store Credit"
    var id: String { rawValue }
}

/// A trade-in quote entered by the user from a real offer (e.g. GameStop's trade-in page).
/// `identifier` is an exact UPC or manufacturer model number used to match retail listings.
struct TradeInQuote: Identifiable, Codable, Equatable {
    var id = UUID()
    var identifier: String
    var label: String
    var tradeValue: Decimal
    var payoutType: PayoutType
    var source: String
    var quotedAt: Date

    var normalizedIdentifier: String {
        identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// A live retail listing returned by an authorized provider.
struct RetailListing: Equatable {
    let sku: String
    let name: String
    let retailer: String
    let price: Decimal
    let upc: String?
    let modelNumber: String?
    let url: URL?
    let fetchedAt: Date
    /// Set for search-based providers: the identifier that was searched for.
    var searchedFor: String? = nil
    /// False when the listing came from a text search and its UPC/model was not confirmed.
    var isExactMatch = true

    func matches(_ quote: TradeInQuote) -> Bool {
        let id = quote.normalizedIdentifier
        guard !id.isEmpty else { return false }
        if upc?.lowercased() == id || modelNumber?.lowercased() == id { return true }
        return searchedFor?.lowercased() == id
    }
}

struct Deal: Identifiable {
    var id: String { "\(listing.retailer)-\(listing.sku)-\(quote.id)" }
    let listing: RetailListing
    let quote: TradeInQuote
    let taxRate: Decimal
    let extraCosts: Decimal

    var name: String { listing.name }
    var retailer: String { listing.retailer }
    var purchasePrice: Decimal { listing.price }
    var tradeValue: Decimal { quote.tradeValue }
    var payoutType: PayoutType { quote.payoutType }

    var totalCost: Decimal {
        purchasePrice + purchasePrice * taxRate + extraCosts
    }

    var netDifference: Decimal {
        tradeValue - totalCost
    }

    var roiPercent: Decimal {
        guard totalCost > 0 else { return 0 }
        return netDifference / totalCost * 100
    }

    /// Quotes older than this are treated as stale and flagged.
    static let staleQuoteInterval: TimeInterval = 7 * 24 * 3600
    func isQuoteStale(now: Date = Date()) -> Bool {
        now.timeIntervalSince(quote.quotedAt) > Deal.staleQuoteInterval
    }

    /// Profitable deals ranked by ROI (highest first), limited to `limit`.
    static func topByROI(_ deals: [Deal], limit: Int = 5) -> [Deal] {
        deals
            .filter { $0.netDifference > 0 }
            .sorted { $0.roiPercent > $1.roiPercent }
            .prefix(limit)
            .map { $0 }
    }
}
