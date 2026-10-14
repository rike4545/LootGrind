import XCTest
@testable import LootGrind

final class DealTests: XCTestCase {
    private func deal(price: Decimal, trade: Decimal, tax: Decimal = 0.10, extra: Decimal = 0,
                      id: String = "123", quotedAt: Date = Date()) -> Deal {
        let listing = RetailListing(sku: id, name: "Item \(id)", retailer: "Best Buy", price: price,
                                    upc: id, modelNumber: nil, url: nil, fetchedAt: Date())
        let quote = TradeInQuote(identifier: id, label: "Item", tradeValue: trade, payoutType: .cash,
                                 source: "Test", quotedAt: quotedAt)
        return Deal(listing: listing, quote: quote, taxRate: tax, extraCosts: extra)
    }

    func testTotalCostIncludesTaxAndExtraCosts() {
        let d = deal(price: 100, trade: 150, extra: 5)
        XCTAssertEqual(d.totalCost, 115)
        XCTAssertEqual(d.netDifference, 35)
    }

    func testTopByROIRanksAndLimitsToFiveExcludingLosses() {
        let deals = (1...7).map { deal(price: 100, trade: Decimal(100 + $0 * 10), id: "\($0)") }
            + [deal(price: 100, trade: 50, id: "loss")]
        let top = Deal.topByROI(deals)
        XCTAssertEqual(top.count, 5)
        XCTAssertEqual(top.first?.listing.sku, "7")
        XCTAssertFalse(top.contains { $0.listing.sku == "loss" })
        XCTAssertEqual(top.map(\.roiPercent), top.map(\.roiPercent).sorted(by: >))
    }

    func testListingMatchesByUPCOrModelCaseInsensitive() {
        let listing = RetailListing(sku: "1", name: "X", retailer: "Best Buy", price: 10,
                                    upc: "0123", modelNumber: "AB-1", url: nil, fetchedAt: Date())
        func quote(_ id: String) -> TradeInQuote {
            TradeInQuote(identifier: id, label: "", tradeValue: 1, payoutType: .cash, source: "", quotedAt: Date())
        }
        XCTAssertTrue(listing.matches(quote("0123")))
        XCTAssertTrue(listing.matches(quote(" ab-1 ")))
        XCTAssertFalse(listing.matches(quote("other")))
        XCTAssertFalse(listing.matches(quote("")))
    }

    func testStaleQuoteDetection() {
        let old = deal(price: 10, trade: 20, quotedAt: Date().addingTimeInterval(-8 * 24 * 3600))
        XCTAssertTrue(old.isQuoteStale())
        XCTAssertFalse(deal(price: 10, trade: 20).isQuoteStale())
    }

    func testRequestURLRejectsUnsafeIdentifiers() {
        XCTAssertNil(BestBuyProvider.requestURL(identifier: "a)&x=(b", apiKey: "k"))
        XCTAssertNil(BestBuyProvider.requestURL(identifier: "123", apiKey: ""))
        XCTAssertNotNil(BestBuyProvider.requestURL(identifier: "123", apiKey: "k"))
    }

    func testSearchBasedListingMatchesQuoteAndIsFlaggedUnverified() {
        let listing = RetailListing(sku: "9", name: "Y", retailer: "Walmart", price: 10, upc: nil,
                                    modelNumber: nil, url: nil, fetchedAt: Date(),
                                    searchedFor: "0123", isExactMatch: false)
        let quote = TradeInQuote(identifier: "0123", label: "", tradeValue: 1, payoutType: .cash,
                                 source: "", quotedAt: Date())
        XCTAssertTrue(listing.matches(quote))
        XCTAssertFalse(listing.isExactMatch)
    }

    func testWalmartRequestURLValidation() {
        XCTAssertNil(WalmartSearchProvider.requestURL(identifier: "a&b", apiKey: "k"))
        XCTAssertNil(WalmartSearchProvider.requestURL(identifier: "123", apiKey: ""))
        XCTAssertNotNil(WalmartSearchProvider.requestURL(identifier: "123", apiKey: "k"))
    }
}
