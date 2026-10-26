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

The Magic: The Gathering tracker also supports TCG API/TCGplayer raw-market snapshots and a separate manual PSA Price Guide field. PSA guide values must be entered after checking the official [PSA Price Guide](https://www.psacard.com/priceguide) for the exact printing and PSA grade. LootGrind does not scrape PSA or claim an automated PSA price feed. Graded guide values are kept separate from raw-card market values and are excluded from raw-market spread calculations; neither is a GameStop trade-in quote. For PSA-graded cards, use GameStop's [graded trading card estimator](https://www.gamestop.com/graded-trading-cards/estimate) to obtain the separate GameStop trade-in estimate, then enter that quote manually. LootGrind does not automatically query GameStop's estimator. The CSV export includes the selected PSA grade, manually entered guide value, and check date.

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


## Daily Magic: The Gathering price publishing

The repository now includes `.github/workflows/refresh-magic-card-prices.yml`, scheduled daily at 12:35 UTC. When a licensed provider is configured, the job fetches its authorized feed, validates the response, writes `data/magic-card-prices.json`, commits changed snapshots, and triggers the GitHub Pages deployment. The public website merges published card records into the Magic tracker so visitors can see the feed's cards, not only browser-local entries.

**This is publishing infrastructure, not a live provider connection yet.** No provider credentials are configured by this change, so daily runs will explicitly report that collection is unavailable and will not invent values or scrape source sites.

### Enable the daily feed

Add these repository secrets under **Settings → Secrets and variables → Actions**:

- `MAGIC_CARD_PRICE_FEED_URL` — HTTPS endpoint for a licensed/authorized provider.
- `MAGIC_CARD_PRICE_FEED_KEY` — bearer token for that provider.

The endpoint must return JSON with a `cards` array. Each record needs exact `name`, `set`, `condition`, and `finish` values, plus at least one numeric source value. Supported numeric fields are `tcgplayerMarket`, `pricechartingPrice`, `cardConduitBuylist`, and `gamestopTradeValue`. Optional fields include `gamestopStatus`, `checkedAt`, `grade`, `collectorNumber`, and `sourceUrls`. Example:

```json
{
  "provider": "Licensed Provider",
  "cards": [
    {
      "name": "Example Card",
      "set": "Example Set",
      "condition": "Near Mint",
      "finish": "nonfoil",
      "tcgplayerMarket": 12.34,
      "pricechartingPrice": 11.25,
      "cardConduitBuylist": 7.5,
      "gamestopTradeValue": null,
      "gamestopStatus": "unverified",
      "checkedAt": "2026-10-25T12:00:00Z",
      "sourceUrls": {}
    }
  ]
}
```

A null or unverified GameStop value is not an offer. The feed must be permitted to provide each source's data; do not scrape TCGplayer, PriceCharting, Card Conduit, or GameStop in violation of their terms. After adding the secrets, use **Actions → Refresh Magic card prices → Run workflow** to test publishing. GitHub Pages then redeploys automatically when `data/magic-card-prices.json` changes.

The website can display market-to-buylist and market-to-trade-in spreads. True ROI requires an actual acquisition cost; market price alone is not a profit estimate. The feed should only label GameStop as verified when it has a genuine eligible quote for the exact card/grade.
