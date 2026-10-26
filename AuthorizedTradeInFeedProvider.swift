import Foundation

/// Adapter for a GameStop-approved or otherwise licensed trade-in feed.
///
/// This intentionally does not crawl GameStop.com. GameStop's Conditions of Use prohibit
/// automated scraping and systematic collection of product listings/prices. Configure this
/// provider only with an endpoint you are authorized to use and that returns the documented
/// LootGrind quote schema.
struct AuthorizedTradeInFeedProvider {
    var endpoint: String
    var apiKey: String
    var session: URLSession = .shared

    private struct FeedQuote: Decodable {
        let identifier: String
        let label: String
        let tradeValue: Decimal
        let payoutType: PayoutType
        let source: String?
        let quotedAt: Date?

        enum CodingKeys: String, CodingKey {
            case identifier, label, tradeValue, payoutType, source, quotedAt
        }
    }

    private struct FeedResponse: Decodable {
        let quotes: [FeedQuote]
    }

    var isConfigured: Bool {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: endpoint),
              let scheme = url.scheme?.lowercased(),
              scheme == "https",
              url.host != nil else { return false }
        return true
    }

    func quotes(for identifier: String) async throws -> [TradeInQuote] {
        guard isConfigured else { throw ProviderError.missingAuthorizedTradeInFeed }
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard var components = URLComponents(string: endpoint) else {
            throw ProviderError.invalidAuthorizedTradeInFeed
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "identifier" }
        items.append(URLQueryItem(name: "identifier", value: trimmed))
        components.queryItems = items
        guard let url = components.url else { throw ProviderError.invalidAuthorizedTradeInFeed }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidAuthorizedTradeInFeed
        }
        guard http.statusCode == 200 else { throw ProviderError.badResponse(http.statusCode) }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(FeedResponse.self, from: data)
        let now = Date()
        return decoded.quotes.compactMap { item in
            let returnedID = item.identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard returnedID.caseInsensitiveCompare(trimmed) == .orderedSame,
                  item.tradeValue > 0 else { return nil }
            return TradeInQuote(
                identifier: returnedID,
                label: item.label,
                tradeValue: item.tradeValue,
                payoutType: item.payoutType,
                source: item.source?.isEmpty == false ? item.source! : "Authorized trade-in feed",
                quotedAt: item.quotedAt ?? now
            )
        }
    }
}
