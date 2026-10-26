#!/usr/bin/env python3
"""Refresh Magic card price snapshots from an authorized/licensed provider feed.

Expected response:
{"provider":"Provider name","cards":[{"name":"Card name","set":"Set / printing","condition":"Near Mint","finish":"nonfoil","tcgplayerMarket":12.34,"pricechartingPrice":11.25,"cardConduitBuylist":7.50,"gamestopTradeValue":null,"gamestopStatus":"unavailable","checkedAt":"ISO-8601"}]}
Only values supplied by the authorized provider are published. Missing GameStop offers remain null.
"""
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "artifacts" / "magic-card-prices.json"
FIELDS = ("tcgplayerMarket", "pricechartingPrice", "cardConduitBuylist", "gamestopTradeValue")
IDENTITY = ("name", "set", "condition", "finish")


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def main():
    endpoint = os.environ.get("MAGIC_CARD_PRICE_FEED_URL", "").strip()
    api_key = os.environ.get("MAGIC_CARD_PRICE_FEED_KEY", "").strip()
    if not endpoint or not api_key:
        fail("Set MAGIC_CARD_PRICE_FEED_URL and MAGIC_CARD_PRICE_FEED_KEY repository secrets for an authorized provider.")
    if not endpoint.startswith("https://"):
        fail("MAGIC_CARD_PRICE_FEED_URL must be HTTPS.")
    request = Request(endpoint, headers={
        "Authorization": f"Bearer {api_key}",
        "Accept": "application/json",
        "User-Agent": "LootGrindMagicPriceRefresh/1.0",
    })
    try:
        with urlopen(request, timeout=30) as response:
            if response.status != 200:
                fail(f"Provider returned HTTP {response.status}.")
            payload = json.loads(response.read().decode("utf-8"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        fail(f"Could not retrieve authorized price feed: {exc}")

    cards = payload.get("cards")
    if not isinstance(cards, list):
        fail("Provider response must contain a cards array.")
    cleaned, seen = [], set()
    for raw in cards:
        if not isinstance(raw, dict) or not all(str(raw.get(k, "")).strip() for k in IDENTITY):
            continue
        item = {k: str(raw[k]).strip() for k in IDENTITY}
        item["finish"] = item["finish"].lower()
        key = tuple(item[k].casefold() for k in IDENTITY)
        if key in seen:
            continue
        seen.add(key)
        valid_count = 0
        for field in FIELDS:
            value = raw.get(field)
            if value is None or value == "":
                item[field] = None
                continue
            try:
                number = float(value)
            except (TypeError, ValueError):
                item[field] = None
                continue
            if number < 0:
                item[field] = None
                continue
            item[field] = round(number, 2)
            valid_count += 1
        item["gamestopStatus"] = str(raw.get("gamestopStatus") or ("verified" if item["gamestopTradeValue"] is not None else "unverified"))
        item["checkedAt"] = str(raw.get("checkedAt") or datetime.now(timezone.utc).isoformat())
        item["sourceUrls"] = raw.get("sourceUrls") if isinstance(raw.get("sourceUrls"), dict) else {}
        item["grade"] = str(raw.get("grade") or "")
        item["collectorNumber"] = str(raw.get("collectorNumber") or "")
        if valid_count:
            cleaned.append(item)

    result = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "provider": str(payload.get("provider") or "authorized Magic pricing feed"),
        "cardCount": len(cleaned),
        "cards": cleaned,
        "note": "Values are copied from an authorized provider feed. Null or unverified GameStop values are not offers.",
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Prepared {len(cleaned)} card price records.")
    if not cleaned:
        fail("No valid card price records returned; snapshot will not be published.")


if __name__ == "__main__":
    main()
