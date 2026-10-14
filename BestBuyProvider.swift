import Foundation

enum ProviderError: LocalizedError {
    case missingAPIKey
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Best Buy API key in the Sources tab."
        case .badResponse(let code): return "Best Buy API returned HTTP \(code)."
        }
    }
}

/// Fetches live prices from the official Best Buy Products API
/// (https://bestbuyapis.github.io/api-documentation/). Requires a free developer key.
protocol ListingProvider {
    var name: String { get }
    var isConfigured: Bool { get }
    func listings(for identifier: String) async throws -> [RetailListing]
}

struct BestBuyProvider: ListingProvider {
    var name: String { "Best Buy" }
    var isConfigured: Bool { !apiKey.isEmpty }
    var apiKey: String
    var session: URLSession = .shared

    private struct Response: Decodable {
        struct Product: Decodable {
            let sku: Int
            let name: String
            let salePrice: Decimal?
            let upc: String?
            let modelNumber: String?
            let url: String?
            let onlineAvailability: Bool?
        }
        let products: [Product]
    }

    static func requestURL(identifier: String, apiKey: String) -> URL? {
        let id = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, !apiKey.isEmpty,
              id.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }) else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.bestbuy.com"
        components.percentEncodedPath = "/v1/products(upc=\(id)%7CmodelNumber=\(id))"
        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "show", value: "sku,name,salePrice,upc,modelNumber,url,onlineAvailability"),
            URLQueryItem(name: "pageSize", value: "10")
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
        return decoded.products.compactMap { p in
            guard let price = p.salePrice, price > 0, p.onlineAvailability != false else { return nil }
            return RetailListing(sku: String(p.sku), name: p.name, retailer: "Best Buy",
                                 price: price, upc: p.upc, modelNumber: p.modelNumber,
                                 url: p.url.flatMap(URL.init(string:)), fetchedAt: now)
        }
    }
}
