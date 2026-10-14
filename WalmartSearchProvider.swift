import Foundation

/// Walmart has no public product-price API, and scraping walmart.com would bypass its access
/// controls. This provider uses a licensed search-data service (SerpApi's Walmart engine,
/// https://serpapi.com/walmart-search-api) that searches by UPC / model number.
/// Search hits are not guaranteed to be the exact product, so listings are flagged as
/// unverified (`isExactMatch == false`) unless the response echoes the identifier back.
struct WalmartSearchProvider: ListingProvider {
    var apiKey: String
    var session: URLSession = .shared
    var maxResults = 3

    var name: String { "Walmart" }
    var isConfigured: Bool { !apiKey.isEmpty }

    private struct Response: Decodable {
        struct Offer: Decodable { let offerPrice: Decimal?
            enum CodingKeys: String, CodingKey { case offerPrice = "offer_price" } }
        struct Result: Decodable {
            let usItemId: String?
            let title: String?
            let upc: String?
            let productPageUrl: String?
            let primaryOffer: Offer?
            enum CodingKeys: String, CodingKey {
                case usItemId = "us_item_id", title, upc
                case productPageUrl = "product_page_url", primaryOffer = "primary_offer"
            }
        }
        let organicResults: [Result]?
        enum CodingKeys: String, CodingKey { case organicResults = "organic_results" }
    }

    static func requestURL(identifier: String, apiKey: String) -> URL? {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !apiKey.isEmpty,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }) else { return nil }
        var components = URLComponents(string: "https://serpapi.com/search.json")!
        components.queryItems = [
            URLQueryItem(name: "engine", value: "walmart"),
            URLQueryItem(name: "query", value: id),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        return components.url
    }

    func listings(for identifier: String) async throws -> [RetailListing] {
        guard !apiKey.isEmpty else { throw ProviderError.missingAPIKey }
        guard let url = Self.requestURL(identifier: identifier, apiKey: apiKey) else { return [] }
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ProviderError.badResponse(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let now = Date()
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return (decoded.organicResults ?? []).prefix(maxResults).compactMap { r in
            guard let price = r.primaryOffer?.offerPrice, price > 0,
                  let title = r.title, let itemId = r.usItemId else { return nil }
            let exact = r.upc?.lowercased() == id.lowercased()
            return RetailListing(sku: itemId, name: title, retailer: "Walmart", price: price,
                                 upc: r.upc, modelNumber: nil,
                                 url: r.productPageUrl.flatMap(URL.init(string:)),
                                 fetchedAt: now, searchedFor: id, isExactMatch: exact)
        }
    }
}
