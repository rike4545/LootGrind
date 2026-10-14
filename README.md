# LootGrind

LootGrind is a native iOS app concept for finding retail-to-trade-in arbitrage opportunities across Best Buy, Walmart, and GameStop.

## Current status

The app contains no demo data. Retail prices are fetched live from the official **Best Buy Products API** (free key from developer.bestbuy.com, entered in the Sources tab). Trade-in values are real quotes you enter (e.g. from GameStop), each stamped with source, payout type and date. Walmart has no public price API, so it is searched automatically through a licensed search-data service (SerpApi); those matches are flagged until verified. Listings are matched to quotes by exact UPC or model number, and the Deals tab ranks the **Top 5 by ROI**. Quotes older than 7 days are flagged as stale.

## Important data-integrity notes

- Do not scrape retailer sites in ways that violate their terms or bypass access controls.
- Integrate authorized product feeds/APIs where available.
- Display the source and last-verified timestamp for every price and trade-in quote.
- Match exact model identifiers, condition, storage, region, and promotion eligibility.
- Keep cash payouts separate from store-credit values.
- Background refresh on iOS is opportunistic, not guaranteed continuous execution. Reliable scheduled scanning requires a backend.

## Background scanner (automatic Top 5)

`scanner/scan.mjs` runs on GitHub Actions (`.github/workflows/scan.yml`, every 6 hours or on demand), fetches current prices for every quote in `scanner/quotes.json`, ranks the Top 5 by ROI and publishes `top-deals.json` to the `scan-results` branch. The app reads it on launch and shows it at the top of the Deals tab. When a *new* deal beats your thresholds it also pushes a notification via [ntfy](https://ntfy.sh).

Setup:
1. In the app's Quotes tab tap the share button and save the export as `scanner/quotes.json` (commit it).
2. Repo Settings → Secrets and variables → Actions: add secrets `BESTBUY_API_KEY`, `SERPAPI_KEY` (Walmart search), `NTFY_TOPIC` (a long random topic name; subscribe to it in the ntfy app). Optional variables: `TAX_PERCENT` (7), `MIN_ROI` (10), `MIN_PROFIT` (5).
3. Run the workflow once (Actions → Scan deals → Run workflow).
4. The app is pre-filled with this repo's feed URL (`https://raw.githubusercontent.com/rike4545/LootGrind/scan-results/top-deals.json`); if you fork, change it in the Sources tab. The app loads the feed on launch and whenever it returns to the foreground, and tags deals it has not shown before as NEW.

Notes: the feed branch is world-readable if the repo is public (private repos need a token the app does not handle yet). SerpApi bills per search, so every extra quote × run costs a search; tune the cron accordingly. GitHub cron is best-effort, not exact. Run `node --test scanner/scan.test.mjs` for the scanner tests.

## Open in Xcode

1. Open `LootGrind.xcodeproj` in Xcode.
2. Select an iOS Simulator or device.
3. Build and run (iOS 17+).

## Next implementation milestones

1. Add a backend scanner so searches run on a schedule (Best Buy and Walmart-via-SerpApi providers are done).
2. Add a GameStop trade-in offer provider and exact-SKU matching.
3. Add a backend scheduled scanner and push notifications.
4. Add location permissions and local pickup availability.
5. Add tests for tax, fees, stale offers, and payout type.

## License

MIT — see `LICENSE`.
