import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DealStore

    var body: some View {
        TabView {
            DealsView()
                .tabItem { Label("Deals", systemImage: "chart.line.uptrend.xyaxis") }
            QuotesView()
                .tabItem { Label("Quotes", systemImage: "tag") }
            SourcesView()
                .tabItem { Label("Sources", systemImage: "antenna.radiowaves.left.and.right") }
        }
        .tint(.green)
        .task { if !store.quotes.isEmpty && !(store.apiKey.isEmpty && store.walmartSearchKey.isEmpty) { await store.refresh() } }
    }
}

private struct DealsView: View {
    @EnvironmentObject private var store: DealStore

    var body: some View {
        NavigationStack {
            List {
                if store.quotes.isEmpty {
                    ContentUnavailableView("No trade-in quotes yet", systemImage: "tag",
                        description: Text("Add a real trade-in quote on the Quotes tab. LootGrind then fetches the live retail price for the exact same product."))
                } else if store.deals.isEmpty {
                    ContentUnavailableView("No matched listings", systemImage: "magnifyingglass",
                        description: Text((store.apiKey.isEmpty && store.walmartSearchKey.isEmpty) ? "Add a Best Buy or Walmart search key in Sources." : "Pull to refresh. Listings must match the quote's UPC or model number exactly."))
                } else {
                    Section("Top 5 by ROI") {
                        let top = store.topDeals
                        if top.isEmpty {
                            Text("No profitable deals right now.").foregroundStyle(.secondary)
                        }
                        ForEach(Array(top.enumerated()), id: \.element.id) { index, deal in
                            NavigationLink { DealDetailView(deal: deal) } label: {
                                DealRow(deal: deal, rank: index + 1)
                            }
                        }
                    }
                    Section("All matched products") {
                        ForEach(store.rankedDeals) { deal in
                            NavigationLink { DealDetailView(deal: deal) } label: {
                                DealRow(deal: deal, rank: nil)
                            }
                        }
                    }
                }
                if let error = store.errorMessage {
                    Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
                }
                if let last = store.lastRefresh {
                    Section { Text("Retail prices fetched \(last.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("LootGrind")
            .refreshable { await store.refresh() }
            .toolbar {
                if store.isRefreshing { ProgressView() }
            }
        }
    }
}

private struct DealRow: View {
    let deal: Deal
    let rank: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("#\(rank)").font(.title3.bold().monospacedDigit()).foregroundStyle(.green)
                    .frame(minWidth: 36)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(deal.name).font(.headline).lineLimit(2)
                Text("\(deal.retailer) · \(deal.payoutType.rawValue)")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !deal.listing.isExactMatch {
                    Text("Search match — verify it's the same product").font(.caption).foregroundStyle(.orange)
                }
                if deal.isQuoteStale() {
                    Text("Trade-in quote is over 7 days old — re-verify").font(.caption).foregroundStyle(.orange)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(NSDecimalNumber(decimal: deal.roiPercent).doubleValue, specifier: "%.1f")%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(deal.netDifference >= 0 ? .green : .red)
                Text(deal.netDifference, format: .currency(code: "USD"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DealDetailView: View {
    let deal: Deal

    var body: some View {
        List {
            LabeledContent("Product", value: deal.name)
            LabeledContent("Retailer", value: deal.retailer)
            LabeledContent("Purchase price", value: deal.purchasePrice, format: .currency(code: "USD"))
            LabeledContent("Estimated tax", value: deal.purchasePrice * deal.taxRate, format: .currency(code: "USD"))
            LabeledContent("Additional costs", value: deal.extraCosts, format: .currency(code: "USD"))
            LabeledContent("Total cost", value: deal.totalCost, format: .currency(code: "USD"))
            LabeledContent("Trade-in value", value: deal.tradeValue, format: .currency(code: "USD"))
            LabeledContent("Payout type", value: deal.payoutType.rawValue)
            LabeledContent("Net difference", value: deal.netDifference, format: .currency(code: "USD"))
            LabeledContent("ROI", value: "\(NSDecimalNumber(decimal: deal.roiPercent).doubleValue.formatted(.number.precision(.fractionLength(1))))%")
            Section("Verification") {
                LabeledContent("Retail price checked", value: deal.listing.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Trade-in source", value: deal.quote.source)
                LabeledContent("Trade-in quoted", value: deal.quote.quotedAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Matched on", value: deal.quote.identifier)
                if !deal.listing.isExactMatch {
                    Text("Found by searching \(deal.quote.identifier); the UPC was not confirmed. Check the listing matches the exact model, condition and storage.")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if let url = deal.listing.url { Link("Open listing", destination: url) }
            }
            if deal.payoutType == .storeCredit {
                Text("Store credit is not cash; its value depends on what you can buy with it.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Text("Confirm the current quote, condition, payout terms and local eligibility before purchasing.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Deal Analysis")
    }
}

private struct QuotesView: View {
    @EnvironmentObject private var store: DealStore
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.quotes) { quote in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(quote.label).font(.headline)
                            Spacer()
                            Text(quote.tradeValue, format: .currency(code: "USD")).monospacedDigit()
                        }
                        Text("\(quote.identifier) · \(quote.payoutType.rawValue) · \(quote.source) · \(quote.quotedAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .onDelete { store.delete(at: $0) }
                if store.quotes.isEmpty {
                    Text("Add a real trade-in quote with the product's UPC or model number.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Trade-in Quotes")
            .toolbar { Button { showingAdd = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $showingAdd) { AddQuoteView() }
        }
    }
}

private struct AddQuoteView: View {
    @EnvironmentObject private var store: DealStore
    @Environment(\.dismiss) private var dismiss
    @State private var label = ""
    @State private var identifier = ""
    @State private var value = ""
    @State private var payout = PayoutType.cash
    @State private var source = "GameStop"
    @State private var quotedAt = Date()

    private var parsedValue: Decimal? { Decimal(string: value) }
    private var isValid: Bool {
        !label.isEmpty && !identifier.trimmingCharacters(in: .whitespaces).isEmpty
            && (parsedValue ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Product name", text: $label)
                TextField("UPC or model number (exact)", text: $identifier)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("Trade-in value (USD)", text: $value).keyboardType(.decimalPad)
                Picker("Payout", selection: $payout) {
                    ForEach(PayoutType.allCases) { Text($0.rawValue).tag($0) }
                }
                TextField("Quote source", text: $source)
                DatePicker("Quoted on", selection: $quotedAt, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("New Quote")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let tradeValue = parsedValue else { return }
                        store.add(TradeInQuote(identifier: identifier, label: label, tradeValue: tradeValue,
                                               payoutType: payout, source: source, quotedAt: quotedAt))
                        Task { await store.refresh() }
                        dismiss()
                    }.disabled(!isValid)
                }
            }
        }
    }
}

private struct SourcesView: View {
    @EnvironmentObject private var store: DealStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Best Buy Products API") {
                    SecureField("API key", text: $store.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Label(store.apiKey.isEmpty ? "Not connected" : "Key saved",
                          systemImage: store.apiKey.isEmpty ? "link.badge.plus" : "checkmark.seal")
                    Link("Get a free key", destination: URL(string: "https://developer.bestbuy.com")!)
                }
                Section("Walmart (via SerpApi search)") {
                    SecureField("SerpApi key", text: $store.walmartSearchKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Label(store.walmartSearchKey.isEmpty ? "Not connected" : "Key saved",
                          systemImage: store.walmartSearchKey.isEmpty ? "link.badge.plus" : "checkmark.seal")
                    Link("Get a key", destination: URL(string: "https://serpapi.com")!)
                    Text("Walmart has no public price API, so LootGrind searches each quote's UPC/model through a licensed search service. Results are flagged until you verify the match.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Sales tax") {
                    Stepper(value: $store.taxPercent, in: 0...15, step: 0.25) {
                        Text("\(store.taxPercent, specifier: "%.2f")%")
                    }
                }
                Section("Manual only") {
                    Label("GameStop: no public trade-in API — enter quotes manually", systemImage: "hand.point.up.left")
                }
                Section {
                    Text("Retail prices come live from authorized APIs. Trade-in values are quotes you enter, each stamped with source and date.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Data Sources")
        }
    }
}
