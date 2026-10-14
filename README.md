# LootGrind

LootGrind is a native iOS app concept for finding retail-to-trade-in arbitrage opportunities across Best Buy, Walmart, and GameStop.

## Current status

The app contains no demo data. Retail prices are fetched live from the official **Best Buy Products API** (free key from developer.bestbuy.com, entered in the Sources tab). Trade-in values are real quotes you enter (e.g. from GameStop), each stamped with source, payout type and date. Listings are matched to quotes by exact UPC or model number, and the Deals tab ranks the **Top 5 by ROI**. Quotes older than 7 days are flagged as stale.

## Important data-integrity notes

- Do not scrape retailer sites in ways that violate their terms or bypass access controls.
- Integrate authorized product feeds/APIs where available.
- Display the source and last-verified timestamp for every price and trade-in quote.
- Match exact model identifiers, condition, storage, region, and promotion eligibility.
- Keep cash payouts separate from store-credit values.
- Background refresh on iOS is opportunistic, not guaranteed continuous execution. Reliable scheduled scanning requires a backend.

## Open in Xcode

1. Open `LootGrind.xcodeproj` in Xcode.
2. Select an iOS Simulator or device.
3. Build and run (iOS 17+).

## Next implementation milestones

1. Add an authorized Walmart product data provider (Best Buy is done).
2. Add a GameStop trade-in offer provider and exact-SKU matching.
3. Add a backend scheduled scanner and push notifications.
4. Add location permissions and local pickup availability.
5. Add tests for tax, fees, stale offers, and payout type.

## License

MIT — see `LICENSE`.
