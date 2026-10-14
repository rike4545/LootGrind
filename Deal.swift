import Foundation

enum PayoutType: String, CaseIterable, Identifiable {
    case cash = "Cash"
    case storeCredit = "Store Credit"
    var id: String { rawValue }
}

struct Deal: Identifiable {
    let id = UUID()
    let name: String
    let retailer: String
    let purchasePrice: Decimal
    let tradeValue: Decimal
    let payoutType: PayoutType
    let taxRate: Decimal
    let extraCosts: Decimal
    let isIllustrative: Bool

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

    static let samples: [Deal] = [
        Deal(name: "iPad (sample listing)", retailer: "Walmart",
             purchasePrice: 299, tradeValue: 340, payoutType: .cash,
             taxRate: Decimal(string: "0.08625")!, extraCosts: 0,
             isIllustrative: true),
        Deal(name: "Game controller (sample listing)", retailer: "Best Buy",
             purchasePrice: 49.99, tradeValue: 35, payoutType: .storeCredit,
             taxRate: Decimal(string: "0.08625")!, extraCosts: 0,
             isIllustrative: true)
    ]
}
