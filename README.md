# LootGrind

LootGrind is a native iOS app concept for finding retail-to-trade-in arbitrage opportunities across Best Buy, Walmart, and GameStop.

## Current status

This repository starter contains the SwiftUI app shell and a transparent deal calculator with sample data. **Sample prices and trade-in values are illustrative only** and are not live offers.

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

1. Add authorized Best Buy and Walmart product data providers.
2. Add a GameStop trade-in offer provider and exact-SKU matching.
3. Add a backend scheduled scanner and push notifications.
4. Add location permissions and local pickup availability.
5. Add tests for tax, fees, stale offers, and payout type.

## License

MIT — see `LICENSE`.
