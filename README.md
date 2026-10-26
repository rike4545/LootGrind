# LootGrind

**Find the spread. Know the profit.**

LootGrind is an independent native iOS project for researching retail-to-trade-in arbitrage opportunities across Best Buy, Walmart, and GameStop. It is designed to compare exact products, keep cash and store-credit values separate, and make stale quotes and hidden costs harder to overlook.

- **Website:** https://rike4545.github.io/LootGrind/
- **Source code:** https://github.com/rike4545/LootGrind
- **License:** MIT

## What it aims to do

- Discover retail prices from supported data sources.
- Match listings and trade-in quotes by exact UPC or model number wherever possible.
- Compare cash and store-credit payout types separately.
- Estimate net spread and ROI after purchase tax and other entered costs.
- Show price sources, verification dates, and stale-quote warnings.
- Help users prioritize opportunities without presenting unverified listings as guaranteed profit.

## Current iOS project status

The app currently includes a SwiftUI interface, deal model/store, Best Buy Products API provider, Walmart search provider, and unit tests. Best Buy requires a developer API key entered in the app. Walmart search results depend on a configured SerpApi key and should be treated as unverified until checked against the retailer listing. Trade-in values are entered as quotes; a live GameStop trade-in integration, backend scheduler, push notifications, and local pickup inventory are not yet complete.

The website includes a standalone profit estimator. Its sample deal card is explicitly illustrative and is not connected to live retailer prices or trade-in offers.

## Website deployment

The static site lives in the repository root:

- `index.html` — page content and metadata
- `styles.css` — responsive dark interface
- `app.js` — client-side profit estimator
- `favicon.svg` — site icon
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow

To publish, open **Settings → Pages** in the repository and select **GitHub Actions** as the build and deployment source. The workflow deploys the root website when site files change on `main`. The first deployment may take a few minutes; confirm the Pages deployment succeeds before sharing the website URL.

## Data integrity principles

- Do not scrape retailer sites in ways that violate their terms or bypass access controls.
- Use authorized product feeds and APIs where available.
- Display the source and last-verified timestamp for every price and trade-in quote.
- Match exact model identifiers, condition, storage, region, and promotion eligibility.
- Keep cash payouts separate from store-credit values.
- Treat background refresh on iOS as opportunistic, not guaranteed continuous execution. Reliable scheduled scanning requires a backend.

## Open the iOS app in Xcode

1. Open `LootGrind.xcodeproj` in Xcode.
2. Select an iOS Simulator or device.
3. Build and run on iOS 17 or later.

## Planned milestones

1. Add a backend scanner for supported retail sources.
2. Add an authorized GameStop trade-in quote source and exact-SKU matching.
3. Add scheduled refresh and push notifications.
4. Add location permissions and local pickup availability.
5. Expand tests for tax, fees, stale offers, payout type, and matching edge cases.

## Disclaimer

LootGrind is an independent project and is not affiliated with, endorsed by, or sponsored by Best Buy, Walmart, or GameStop. Prices, inventory, promotions, and trade-in values change and may have eligibility requirements. Verify all details directly before making a purchase.

## License

MIT — see [LICENSE](LICENSE).
