import Foundation

/// One ranked deal produced by the background scanner (scanner/scan.mjs).
struct ScanDeal: Codable, Identifiable, Equatable {
    let id: String
    let rank: Int
    let name: String
    let retailer: String
    let price: Double
    let tradeValue: Double
    let payoutType: String
    let totalCost: Double
    let netDifference: Double
    let roiPercent: Double
    let url: URL?
    let isExactMatch: Bool
    let quoteSource: String
    let quotedAt: Date
    let quoteStale: Bool
}

struct ScanFeed: Codable, Equatable {
    let generatedAt: Date
    let taxPercent: Double
    let matched: Int
    let errors: [String]
    let top: [ScanDeal]

    static func decode(_ data: Data) throws -> ScanFeed {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ScanFeed.self, from: data)
    }
}
