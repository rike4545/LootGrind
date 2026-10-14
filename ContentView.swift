import SwiftUI

struct ContentView: View {
    @State private var minimumProfit = 25.0
    @State private var selectedTab = 0

    private var deals: [Deal] {
        Deal.samples.filter { NSDecimalNumber(decimal: $0.netDifference).doubleValue >= minimumProfit }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Find the spread.")
                                .font(.largeTitle.bold())
                            Text("Compare retail prices with trade-in offers. Only verified data should drive a buy decision.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    Section("Minimum net difference") {
                        VStack(alignment: .leading) {
                            Text(minimumProfit, format: .currency(code: "USD").precision(.fractionLength(0)))
                                .font(.title2.bold())
                                .foregroundStyle(.green)
                            Slider(value: $minimumProfit, in: 0...100, step: 5)
                                .tint(.green)
                        }
                    }
                    Section("Potential opportunities") {
                        if deals.isEmpty {
                            ContentUnavailableView("No matching sample deals", systemImage: "magnifyingglass",
                                                   description: Text("Lower the threshold or connect verified data sources."))
                        } else {
                            ForEach(deals) { deal in
                                NavigationLink {
                                    DealDetailView(deal: deal)
                                } label: {
                                    DealRow(deal: deal)
                                }
                            }
                        }
                    }
                    Section {
                        Label("Sample data only — not live offers", systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
                .navigationTitle("LootGrind")
            }
            .tabItem { Label("Deals", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(0)

            NavigationStack {
                List {
                    Label("Best Buy provider: not connected", systemImage: "link")
                    Label("Walmart provider: not connected", systemImage: "link")
                    Label("GameStop trade-in provider: not connected", systemImage: "link")
                    Text("Use authorized data sources and record a timestamp for each quote.")
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Data Sources")
            }
            .tabItem { Label("Sources", systemImage: "antenna.radiowaves.left.and.right") }
            .tag(1)
        }
        .tint(.green)
    }
}

private struct DealRow: View {
    let deal: Deal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(deal.name).font(.headline)
                Spacer()
                Text(deal.netDifference, format: .currency(code: "USD"))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(deal.netDifference >= 0 ? .green : .red)
            }
            Text("\(deal.retailer) · \(deal.payoutType.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Illustrative estimate · tax included")
                .font(.caption)
                .foregroundStyle(.orange)
        }
        .padding(.vertical, 4)
    }
}

private struct DealDetailView: View {
    let deal: Deal

    var body: some View {
        List {
            LabeledContent("Retailer", value: deal.retailer)
            LabeledContent("Purchase price", value: deal.purchasePrice, format: .currency(code: "USD"))
            LabeledContent("Estimated tax", value: deal.purchasePrice * deal.taxRate, format: .currency(code: "USD"))
            LabeledContent("Additional costs", value: deal.extraCosts, format: .currency(code: "USD"))
            LabeledContent("Total estimated cost", value: deal.totalCost, format: .currency(code: "USD"))
            LabeledContent("Trade-in estimate", value: deal.tradeValue, format: .currency(code: "USD"))
            LabeledContent("Payout type", value: deal.payoutType.rawValue)
            LabeledContent("Net difference", value: deal.netDifference, format: .currency(code: "USD"))
            LabeledContent("ROI", value: "\(NSDecimalNumber(decimal: deal.roiPercent).doubleValue, specifier: "%.1f")%")
            Text("Illustrative values only. Confirm the current quote, product condition, payout terms, and local eligibility before purchasing.")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        .navigationTitle("Deal Analysis")
    }
}
