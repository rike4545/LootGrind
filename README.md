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

The app currently includes a SwiftUI interface, deal model/store, Best Buy Products API provider, Walmart search provider, and unit tests. Best Buy requires a developer API key entered in the app. Walmart search results depend on a configured SerpApi key and should be treated as unverified until checked against the retailer listing. Trade-in values can be entered manually or refreshed through the authorized-feed adapter when you have an approved/licensed feed endpoint. There is no direct GameStop integration bundled, and backend scheduling, push notifications, and local pickup inventory are not yet complete.

The website includes a standalone profit estimator. Its sample deal card is explicitly illustrative and is not connected to live retailer prices or trade-in offers.

## Website deployment

The static site lives in the repository root:

- `index.html` — page content and metadata
- `styles.css` — responsive dark interface
- `app.js` — client-side profit estimator
- `favicon.svg` — site icon
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow

To publish, open **Settings → Pages** in the repository and select **GitHub Actions** as the build and deployment source. The workflow deploys the root website when site files change on `main`. The first deployment may take a few minutes; confirm the Pages deployment succeeds before sharing the website URL.

## GameStop trade-in data: authorized feed adapter

GameStop's [Conditions of Use](https://www.gamestop.com/disclaimer.html) prohibit automated scraping and systematic collection of site listings/prices without authorization. LootGrind therefore does **not** scrape GameStop.com or bypass its access controls. The iOS Sources screen includes an adapter for an API/feed you are authorized to use. Until an approved source is configured, add quotes manually and verify them on [GameStop's trade-in page](https://www.gamestop.com/trade/).

### Feed contract

Configure an HTTPS endpoint and bearer API key in **Sources → Authorized trade-in feed**. LootGrind sends a GET request with an `identifier` query parameter containing the exact UPC or model number and an `Authorization: Bearer …` header. The feed must return JSON in this shape:

```json
{
  "quotes": [
    {
      "identifier": "012345678905",
      "label": "Example console 1 TB",
      "tradeValue": 125.00,
      "payoutType": "Cash",
      "source": "Authorized Provider",
      "quotedAt": "2026-10-25T12:00:00Z"
    }
  ]
}
```

- `identifier` must exactly match the requested UPC/model (case-insensitive).
- `tradeValue` must be a positive number.
- `payoutType` must be `Cash` or `Store Credit`.
- `quotedAt` is an ISO-8601 timestamp; if omitted, the retrieval time is used.
- `source` identifies the licensed provider; if omitted, LootGrind labels it as an authorized trade-in feed.
- The adapter refreshes quotes for identifiers already in LootGrind. It does not discover the entire GameStop catalog by itself.

**Important:** This is a connector adapter, not a GameStop API key or a claim that GameStop offers a public trade-in API. Do not enter a GameStop website URL as the feed endpoint. A working feed requires a provider endpoint and credentials that you are permitted to use.

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
