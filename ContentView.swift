import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DealStore
    @Environment(\.scenePhase) private var scenePhase

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
        .task { await store.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.refresh() } }
        }
    }
}

private func roiText(_ d: Decimal) -> String {
    let v = NSDecimalNumber(decimal: d).doubleValue
    return (v >= 0 ? "+" : "") + v.formatted(.number.precision(.fractionLength(1))) + "%"
}

private struct RetailerChip: View {
    let retailer: String
    var color: Color { retailer == "Walmart" ? .blue : retailer == "Best Buy" ? .yellow : .gray }
    var body: some View {
        Text(retailer).font(.caption2.bold())
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.2), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct DealsView: View {
    @EnvironmentObject private var store: DealStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let feed = store.scanFeed, !feed.top.isEmpty {
                        ScanSection(feed: feed)
                    }
                    let hasScan = !(store.scanFeed?.top.isEmpty ?? true)
                    if store.quotes.isEmpty {
                        if !hasScan {
                            ContentUnavailableView("No trade-in quotes yet", systemImage: "tag",
                                description: Text("Add a real trade-in quote on the Quotes tab, or connect the background scanner in Sources."))
                        }
                    } else if store.deals.isEmpty {
                        if !hasScan || !(store.apiKey.isEmpty && store.walmartSearchKey.isEmpty) {
                        ContentUnavailableView("No matched listings", systemImage: "magnifyingglass",
                            description: Text((store.apiKey.isEmpty && store.walmartSearchKey.isEmpty) ? "Add a Best Buy or Walmart search key in Sources." : "Pull down to refresh."))
                        }
                    } else {
                        summary
                        let top = store.topDeals
                        if let best = top.first {
                            NavigationLink { DealDetailView(deal: best) } label: { HeroCard(deal: best) }
                                .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(hasScan ? "Live check · Top 5 by ROI" : "Top 5 by ROI").font(.title3.bold())
                            if top.isEmpty {
                                Text("No profitable deals right now.").foregroundStyle(.secondary)
                            }
                            ForEach(Array(top.enumerated()), id: \.element.id) { index, deal in
                                NavigationLink { DealDetailView(deal: deal) } label: {
                                    DealRow(deal: deal, rank: index + 1)
                                }.buttonStyle(.plain)
                            }
                        }
                        let rest = store.rankedDeals.filter { d in !top.contains { $0.id == d.id } }
                        if !rest.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other matches").font(.title3.bold())
                                ForEach(rest) { deal in
                                    NavigationLink { DealDetailView(deal: deal) } label: {
                                        DealRow(deal: deal, rank: nil)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if let error = store.errorMessage {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote).foregroundStyle(.red)
                    }
                    if let last = store.lastRefresh {
                        Text("Prices checked \(last.formatted(.relative(presentation: .named)))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("LootGrind")
            .refreshable { await store.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if store.isRefreshing { ProgressView() }
                    else { Button { Task { await store.refresh() } } label: { Image(systemName: "arrow.clockwise") } }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            stat("\(store.deals.count)", "Matches")
            stat("\(store.deals.filter { $0.netDifference > 0 }.count)", "Profitable")
            stat(store.topDeals.first.map { roiText($0.roiPercent) } ?? "—", "Best ROI")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.bold().monospacedDigit()).foregroundStyle(.green)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ScanSection: View {
    @EnvironmentObject private var store: DealStore
    let feed: ScanFeed
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Background scan · Top 5 by ROI", systemImage: "clock.arrow.2.circlepath").font(.title3.bold())
            }
            Text("Updated \(feed.generatedAt.formatted(.relative(presentation: .named))) · tax \(feed.taxPercent.formatted())%")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(feed.top) { deal in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text("\(deal.rank)").font(.headline.monospacedDigit()).foregroundStyle(.black)
                            .frame(width: 30, height: 30).background(.green, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(deal.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                if store.newScanDealIDs.contains(deal.id) {
                                    Text("NEW").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.green, in: Capsule()).foregroundStyle(.black)
                                }
                            }
                            HStack(spacing: 6) {
                                RetailerChip(retailer: deal.retailer)
                                Text("Buy \(deal.price.formatted(.currency(code: "USD"))) → trade \(deal.tradeValue.formatted(.currency(code: "USD"))) · \(deal.payoutType)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(roiText(Decimal(deal.roiPercent))).font(.headline.monospacedDigit()).foregroundStyle(.green)
                            Text(deal.netDifference.formatted(.currency(code: "USD")))
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                    if !deal.isExactMatch {
                        Label("Verify match", systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange)
                    }
                    if deal.quoteStale {
                        Label("Quote over 7 days old", systemImage: "clock.badge.exclamationmark").font(.caption2).foregroundStyle(.orange)
                    }
                    if let url = deal.url {
                        Link(destination: url) { Label("Open listing", systemImage: "arrow.up.right.square").font(.caption) }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            ForEach(feed.errors, id: \.self) { Label($0, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red) }
        }
    }
}

private struct HeroCard: View {
    let deal: Deal
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Best deal", systemImage: "trophy.fill").font(.caption.bold()).foregroundStyle(.green)
                Spacer()
                RetailerChip(retailer: deal.retailer)
            }
            Text(deal.name).font(.headline).lineLimit(2)
            HStack(alignment: .firstTextBaseline) {
                Text(roiText(deal.roiPercent)).font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(.green)
                Text("ROI").foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(deal.netDifference, format: .currency(code: "USD")).font(.title3.bold().monospacedDigit())
                    Text("net profit").font(.caption).foregroundStyle(.secondary)
                }
            }
            if !deal.listing.isExactMatch {
                Label("Verify match", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(LinearGradient(colors: [.green.opacity(0.28), .green.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.green.opacity(0.4)))
    }
}

private struct DealRow: View {
    let deal: Deal
    let rank: Int?

    var body: some View {
        HStack(spacing: 12) {
            if let rank {
                Text("\(rank)").font(.headline.monospacedDigit()).foregroundStyle(.black)
                    .frame(width: 30, height: 30).background(.green, in: Circle())
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(deal.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                HStack(spacing: 6) {
                    RetailerChip(retailer: deal.retailer)
                    Text(deal.payoutType.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: min(max(NSDecimalNumber(decimal: deal.roiPercent).doubleValue, 0), 100), total: 100)
                    .tint(.green)
                if !deal.listing.isExactMatch {
                    Label("Verify match", systemImage: "exclamationmark.circle").font(.caption2).foregroundStyle(.orange)
                }
                if deal.isQuoteStale() {
                    Label("Quote over 7 days old", systemImage: "clock.badge.exclamationmark").font(.caption2).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(roiText(deal.roiPercent)).font(.headline.monospacedDigit())
                    .foregroundStyle(deal.netDifference >= 0 ? .green : .red)
                Text(deal.netDifference, format: .currency(code: "USD"))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DealDetailView: View {
    let deal: Deal

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    RetailerChip(retailer: deal.retailer)
                    Text(deal.name).font(.headline)
                    Text(roiText(deal.roiPercent)).font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(deal.netDifference >= 0 ? .green : .red)
                    Text("\(deal.netDifference.formatted(.currency(code: "USD"))) net after tax")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 4)
            }
            Section("Cost") {
                LabeledContent("Purchase price", value: deal.purchasePrice, format: .currency(code: "USD"))
                LabeledContent("Estimated tax", value: deal.purchasePrice * deal.taxRate, format: .currency(code: "USD"))
                LabeledContent("Additional costs", value: deal.extraCosts, format: .currency(code: "USD"))
                LabeledContent("Total cost", value: deal.totalCost, format: .currency(code: "USD")).bold()
            }
            Section("Payout") {
                LabeledContent("Trade-in value", value: deal.tradeValue, format: .currency(code: "USD"))
                LabeledContent("Payout type", value: deal.payoutType.rawValue)
            }
            Section("Verification") {
                LabeledContent("Retail price checked", value: deal.listing.fetchedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Trade-in source", value: deal.quote.source)
                LabeledContent("Trade-in quoted", value: deal.quote.quotedAt.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Matched on", value: deal.quote.identifier)
                if let url = deal.listing.url { Link(destination: url) { Label("Open listing", systemImage: "arrow.up.right.square") } }
            }
            if !deal.listing.isExactMatch {
                Label("Found by search; the UPC was not confirmed. Check the listing is the exact model, condition and storage.",
                      systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
            if deal.payoutType == .storeCredit {
                Label("Store credit is not cash; its value depends on what you can buy with it.",
                      systemImage: "creditcard").font(.footnote).foregroundStyle(.orange)
            }
            Text("Confirm the current quote, condition, payout terms and local eligibility before purchasing.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Deal Analysis")
        .navigationBarTitleDisplayMode(.inline)
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.quotes.isEmpty {
                        ShareLink(item: store.exportedQuotesJSON, subject: Text("quotes.json"),
                                  message: Text("Save as scanner/quotes.json in your LootGrind repo")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
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
                Section("Background scanner") {
                    TextField("Feed URL (top-deals.json)", text: $store.feedURL)
                        .font(.footnote)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    Label(store.scanFeed.map { "Last scan \($0.generatedAt.formatted(.relative(presentation: .named)))" } ?? "Not connected",
                          systemImage: store.scanFeed == nil ? "link.badge.plus" : "checkmark.seal")
                    Text("A GitHub Actions job scans on a schedule and publishes the Top 5. Set it up from the README (the feed URL below is pre-filled), and install the free ntfy app to get a push when a new deal appears.")
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
