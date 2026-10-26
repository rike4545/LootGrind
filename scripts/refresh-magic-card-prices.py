#!/usr/bin/env python3
"""Publish a daily Magic: The Gathering market-price snapshot from TCG API.

Requires the repository Actions secret TCG_API_KEY. This uses one search request
per watchlist query (the free tier documents 100 requests/day). It does not scrape
retailer websites or claim that market prices are GameStop trade-in offers.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WATCHLIST = ROOT / "data" / "magic-card-watchlist.json"
OUTPUT = ROOT / "artifacts" / "magic-card-prices.json"
API_URL = "https://api.tcgapi.dev/v1/search"
USER_AGENT = "LootGrindMagicPriceRefresh/1.0"


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def normalized(value):
    return re.sub(r"[^a-z0-9]", "", str(value or "").lower())


def fetch_search(query, api_key):
    url = API_URL + "?" + urlencode({"game": "magic", "q": query, "per_page": 100})
    request = Request(url, headers={
        "X-API-Key": api_key,
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    })
    try:
        with urlopen(request, timeout=30) as response:
            if response.status != 200:
                fail(f"TCG API returned HTTP {response.status} for a watchlist query.")
            payload = json.loads(response.read().decode("utf-8"))
    except HTTPError as exc:
        fail(f"TCG API returned HTTP {exc.code}; check TCG_API_KEY and your plan limits.")
    except (URLError, TimeoutError, json.JSONDecodeError) as exc:
        fail(f"Could not retrieve TCG API prices: {exc}")
    data = payload.get("data")
    if not isinstance(data, list):
        fail("TCG API response did not contain the expected data array.")
    return data


def main():
    api_key = os.environ.get("TCG_API_KEY", "").strip()
    if not api_key:
        fail("Add the TCG_API_KEY repository Actions secret before running this workflow.")

    try:
        watchlist = json.loads(WATCHLIST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"Could not read data/magic-card-watchlist.json: {exc}")
    if not isinstance(watchlist, list) or not watchlist:
        fail("The Magic watchlist must be a non-empty JSON array.")

    checked_at = datetime.now(timezone.utc).isoformat()
    cards_by_key = {}
    queries_used = 0
    for entry in watchlist:
        if not isinstance(entry, dict):
            continue
        query = str(entry.get("query") or entry.get("name") or "").strip()
        target_name = str(entry.get("name") or query).strip()
        if len(query) < 2 or not target_name:
            continue
        results = fetch_search(query, api_key)
        queries_used += 1
        target = normalized(target_name)
        for raw in results:
            if not isinstance(raw, dict) or normalized(raw.get("name")) != target:
                continue
            set_name = str(raw.get("set_name") or "").strip()
            if not set_name:
                continue
            printing = str(raw.get("printing") or ("Foil" if raw.get("foil_only") else "Normal")).strip()
            finish = "foil" if "foil" in printing.lower() else "nonfoil"
            price = raw.get("market_price")
            try:
                market = round(float(price), 2) if price is not None and float(price) >= 0 else None
            except (TypeError, ValueError):
                market = None
            key = (target, normalized(set_name), finish)
            item = {
                "name": str(raw.get("name") or target_name),
                "set": set_name,
                "condition": "Near Mint",
                "finish": finish,
                "tcgplayerMarket": market,
                "pricechartingPrice": None,
                "cardConduitBuylist": None,
                "gamestopTradeValue": None,
                "gamestopStatus": "unavailable",
                "checkedAt": str(raw.get("price_updated_at") or raw.get("market_price_as_of") or checked_at),
                "grade": "",
                "collectorNumber": str(raw.get("number") or ""),
                "sourceUrls": {
                    "tcgplayerMarket": "https://www.tcgplayer.com/search/magic/product?q=" + __import__("urllib.parse", fromlist=["quote"]).quote(str(raw.get("name") or target_name) + " " + set_name),
                    "tcgApi": "https://tcgapi.dev/",
                },
            }
            existing = cards_by_key.get(key)
            if existing is None or (existing["tcgplayerMarket"] is None and market is not None):
                cards_by_key[key] = item

    cards = sorted(cards_by_key.values(), key=lambda c: (c["name"].casefold(), c["set"].casefold(), c["finish"]))
    if not cards:
        fail("No exact card-name matches were returned; no snapshot was published.")

    result = {
        "generatedAt": checked_at,
        "provider": "TCG API (TCGplayer market data)",
        "queryCount": queries_used,
        "cardCount": len(cards),
        "cards": cards,
        "note": "TCG API market prices only. PriceCharting, Card Conduit, and GameStop values are unavailable unless separately verified from an authorized source. Market price is not a trade-in offer or guaranteed acquisition cost.",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(cards)} exact-name printing records from {queries_used} search requests.")


if __name__ == "__main__":
    main()
