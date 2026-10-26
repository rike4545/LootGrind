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

The app currently includes a SwiftUI interface, deal model/store, Best Buy Products API provider, Walmart search provider, and unit tests. Best Buy requires a developer API key entered in the app. Walmart search results depend on a configured SerpApi key and should be treated as unverified until checked against the retailer listing. Trade-in values can be entered manually or refreshed through the authorized-feed adapter when you have an approved/licensed feed endpoint. A daily GitHub Actions job now supports scheduled refreshes from that authorized feed; it requires provider credentials and a populated watchlist before it can run successfully. There is no direct GameStop integration bundled.

The website includes a product-research watchlist, an opportunity scanner, a profit estimator, and a ranking. When the scheduled authorized-feed workflow is configured and succeeds, it publishes `data/trade-in-quotes.json`, which the website loads automatically and uses to populate trade-in quotes and payout types. Users can manually override quotes. Retail purchase prices, tax, and extra costs remain user-entered, and are stored in the current browser and can be exported as CSV. Entries do not sync across devices. Without an authorized feed configured, the site cannot automatically fetch GameStop trade-in values.

## Website deployment

The static site lives in the repository root:

- `index.html` — page content and metadata
- `styles.css` — responsive dark interface
- `app.js` — client-side profit estimator
- `favicon.svg` — site icon
- `.github/workflows/pages.yml` — GitHub Pages deployment workflow

To publish, open **Settings → Pages** in the repository and select **GitHub Actions** as the build and deployment source. The workflow deploys the root website when site files or `data/trade-in-quotes.json` change on `main`, so a newly published quote snapshot is included in the Pages deployment. The first deployment may take a few minutes; confirm the Pages deployment succeeds before sharing the website URL.

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
- The iOS adapter refreshes identifiers already in the app. The scheduled backend job reads identifiers from `data/trade-in-watchlist.json`, queries the configured feed for each one, validates matching identifiers and payout values, and uploads a JSON snapshot as a GitHub Actions artifact named `lootgrind-trade-in-quotes` (retained for 14 days). It does not discover the entire GameStop catalog by itself.

**Important:** This is a connector adapter and scheduled feed poller, not a GameStop API key or a claim that GameStop offers a public trade-in API. Do not enter a GameStop website URL as the feed endpoint. A working feed requires a provider endpoint and credentials that you are permitted to use.

### Enable scheduled refresh

1. Review `data/trade-in-watchlist.json`. The placeholder has been replaced with manufacturer model identifiers for several popular Nintendo, PlayStation, and Xbox products. Confirm the exact model/region/edition before relying on a match.
2. In **Settings → Secrets and variables → Actions**, add repository secrets named `TRADE_IN_FEED_URL` and `TRADE_IN_FEED_KEY` for your licensed provider.
3. Open **Actions → Refresh authorized trade-in quotes** and choose **Run workflow** to test it. Once configured, it runs daily at 12:20 UTC. Until credentials are configured, the scheduled workflow only reports that live collection is unavailable and does not fail the run.
4. Open the successful run and confirm the `data/trade-in-quotes.json` snapshot commit and/or download the `lootgrind-trade-in-quotes` artifact. The refresh script intentionally fails when run directly without credentials or when no valid quotes are returned; the scheduled workflow skips collection when credentials are missing.

After a successful authorized-feed refresh, the workflow publishes the validated snapshot to `data/trade-in-quotes.json` for the website and also uploads the `lootgrind-trade-in-quotes` artifact. The website fetches the public JSON snapshot automatically. The workflow still does not discover the whole GameStop catalog; it only queries identifiers in the watchlist.

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

1. Connect a licensed trade-in feed and populate the scheduled watchlist.
2. Publish quote snapshots to a secure API consumable by the app.
3. Add push notifications and local pickup availability.
4. Expand tests for tax, fees, stale offers, payout type, and matching edge cases.

## Disclaimer

LootGrind is an independent project and is not affiliated with, endorsed by, or sponsored by Best Buy, Walmart, or GameStop. Prices, inventory, promotions, and trade-in values change and may have eligibility requirements. Verify all details directly before making a purchase.

## License

MIT — see [LICENSE](LICENSE).
