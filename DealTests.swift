import XCTest
@testable import LootGrind

final class DealTests: XCTestCase {
    func testTotalCostIncludesTaxAndExtraCosts() {
        let deal = Deal(name: "Test", retailer: "Test Retailer",
                        purchasePrice: 100, tradeValue: 150, payoutType: .cash,
                        taxRate: Decimal(string: "0.10")!, extraCosts: 5,
                        isIllustrative: false)
        XCTAssertEqual(deal.totalCost, 115)
        XCTAssertEqual(deal.netDifference, 35)
    }
}
