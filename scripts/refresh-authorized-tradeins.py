#!/usr/bin/env python3
"""Refresh trade-in quotes from a licensed HTTPS provider; never crawls retailer pages."""
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlparse, parse_qsl, urlunparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
WATCHLIST = ROOT / "data" / "trade-in-watchlist.json"
OUTPUT = ROOT / "artifacts" / "trade-in-quotes.json"


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main():
    endpoint = os.environ.get("TRADE_IN_FEED_URL", "").strip()
    api_key = os.environ.get("TRADE_IN_FEED_KEY", "").strip()
    if not endpoint or not api_key:
        fail("Set TRADE_IN_FEED_URL and TRADE_IN_FEED_KEY as GitHub Actions secrets.")
    parsed = urlparse(endpoint)
    if parsed.scheme != "https" or not parsed.netloc:
        fail("TRADE_IN_FEED_URL must be a valid HTTPS endpoint.")

    try:
        watchlist = json.loads(WATCHLIST.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"Cannot read watchlist: {exc}")
    identifiers = watchlist.get("identifiers", [])
    if not isinstance(identifiers, list) or not identifiers:
        fail("Add one or more UPC/model identifiers to data/trade-in-watchlist.json.")

    collected, failures = [], []
    for identifier in identifiers:
        identifier = str(identifier).strip()
        if not identifier:
            continue
        query = dict(parse_qsl(parsed.query, keep_blank_values=True))
        query["identifier"] = identifier
        url = urlunparse(parsed._replace(query=urlencode(query)))
        request = Request(url, headers={
            "Authorization": f"Bearer {api_key}",
            "Accept": "application/json",
            "User-Agent": "LootGrindAuthorizedFeedRefresh/1.0",
        })
        try:
            with urlopen(request, timeout=20) as response:
                if response.status != 200:
                    raise ValueError(f"HTTP {response.status}")
                payload = json.loads(response.read().decode("utf-8"))
            quotes = payload.get("quotes")
            if not isinstance(quotes, list):
                raise ValueError("response must contain a quotes array")
            for quote in quotes:
                if str(quote.get("identifier", "")).strip().casefold() != identifier.casefold():
                    continue
                value = float(quote.get("tradeValue", 0))
                payout = quote.get("payoutType")
                if value <= 0 or payout not in ("Cash", "Store Credit"):
                    continue
                quote["tradeValue"] = round(value, 2)
                quote["source"] = quote.get("source") or "Authorized trade-in feed"
                quote["quotedAt"] = quote.get("quotedAt") or datetime.now(timezone.utc).isoformat()
                collected.append(quote)
        except (HTTPError, URLError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
            failures.append({"identifier": identifier, "error": str(exc)})
        time.sleep(0.25)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    result = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "provider": "authorized feed",
        "quoteCount": len(collected),
        "quotes": collected,
        "failures": failures,
        "note": "Only authorized feed data is included; this job does not scrape retailer websites.",
    }
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Saved {len(collected)} validated quote(s); {len(failures)} identifier(s) failed.")
    if failures:
        print(json.dumps(failures, indent=2))
    if not collected:
        fail("No valid quotes returned. Check the watchlist, feed response, and credentials.")


if __name__ == "__main__":
    main()
