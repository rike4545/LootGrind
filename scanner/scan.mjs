#!/usr/bin/env node
// LootGrind background scanner. Reads scanner/quotes.json, fetches current retail prices
// (Best Buy Products API, Walmart via SerpApi), ranks deals by ROI and writes a JSON feed
// the iOS app reads. Optionally pushes new top deals to your phone through ntfy.sh.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const STALE_MS = 7 * 24 * 3600 * 1000;
const SAFE_ID = /^[A-Za-z0-9.\-]+$/;
const round2 = (n) => Math.round(n * 100) / 100;
const iso = (d) => new Date(d).toISOString().replace(/\.\d{3}Z$/, 'Z');

export function evaluate(listing, quote, taxPercent, now = Date.now()) {
  const totalCost = round2(listing.price * (1 + taxPercent / 100));
  const netDifference = round2(quote.tradeValue - totalCost);
  const roiPercent = totalCost > 0 ? round2((netDifference / totalCost) * 100) : 0;
  const quotedAt = new Date(quote.quotedAt).getTime();
  return {
    id: `${listing.retailer}-${listing.sku}-${String(quote.identifier).trim().toLowerCase()}`,
    name: listing.name,
    retailer: listing.retailer,
    price: listing.price,
    tradeValue: quote.tradeValue,
    payoutType: quote.payoutType,
    totalCost,
    netDifference,
    roiPercent,
    url: listing.url ?? null,
    isExactMatch: listing.isExactMatch,
    quoteSource: quote.source,
    quotedAt: iso(quotedAt),
    quoteStale: now - quotedAt > STALE_MS,
  };
}

export function rank(deals, limit = 5) {
  return deals
    .filter((d) => d.netDifference > 0)
    .sort((a, b) => b.roiPercent - a.roiPercent)
    .slice(0, limit)
    .map((d, i) => ({ ...d, rank: i + 1 }));
}

export function newDeals(current, previousFeed) {
  const seen = new Set((previousFeed?.top ?? []).map((d) => d.id));
  return current.filter((d) => !seen.has(d.id));
}

async function getJson(url, fetchFn) {
  const res = await fetchFn(url, { signal: AbortSignal.timeout(20000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

export async function bestBuyListings(id, key, fetchFn = fetch) {
  if (!SAFE_ID.test(id)) return [];
  const query = new URLSearchParams({
    apiKey: key,
    format: 'json',
    show: 'sku,name,salePrice,url,onlineAvailability',
    pageSize: '10',
  });
  const url = `https://api.bestbuy.com/v1/products(upc=${id}%7CmodelNumber=${id})?${query}`;
  const data = await getJson(url, fetchFn);
  return (data.products ?? [])
    .filter((p) => p.salePrice > 0 && p.onlineAvailability !== false)
    .map((p) => ({ sku: String(p.sku), name: p.name, retailer: 'Best Buy',
                   price: p.salePrice, url: p.url, isExactMatch: true }));
}

export async function walmartListings(id, key, fetchFn = fetch, max = 3) {
  if (!SAFE_ID.test(id)) return [];
  const query = new URLSearchParams({ engine: 'walmart', query: id, api_key: key });
  const data = await getJson(`https://serpapi.com/search.json?${query}`, fetchFn);
  return (data.organic_results ?? []).slice(0, max)
    .filter((r) => r.primary_offer?.offer_price > 0 && r.title && r.us_item_id)
    .map((r) => ({ sku: String(r.us_item_id), name: r.title, retailer: 'Walmart',
                   price: r.primary_offer.offer_price, url: r.product_page_url ?? null,
                   isExactMatch: String(r.upc ?? '').toLowerCase() === id.toLowerCase() }));
}

async function readJson(path, fallback) {
  try { return JSON.parse(await readFile(path, 'utf8')); } catch { return fallback; }
}

async function notify(topic, deals) {
  const best = deals[0];
  const lines = deals.slice(0, 5).map((d) =>
    `#${d.rank} ${d.roiPercent.toFixed(1)}% ROI: ${d.name} - buy ${d.retailer} $${d.price}, ` +
    `trade $${d.tradeValue} (${d.payoutType})${d.isExactMatch ? '' : ' [verify match]'}`);
  const headers = { Title: `LootGrind: ${deals.length} new deal${deals.length > 1 ? 's' : ''}`,
                    Priority: 'high', Tags: 'moneybag' };
  if (best.url) headers.Click = best.url;
  await fetch(`https://ntfy.sh/${encodeURIComponent(topic)}`,
              { method: 'POST', headers, body: lines.join('\n') });
}

export async function main(env = process.env) {
  const taxPercent = Number(env.TAX_PERCENT ?? 7);
  const minRoi = Number(env.MIN_ROI ?? 10);
  const minProfit = Number(env.MIN_PROFIT ?? 5);
  const out = env.OUT ?? 'out/top-deals.json';
  const quotes = await readJson(env.QUOTES ?? 'scanner/quotes.json', []);
  const previous = await readJson(env.PREV_FEED ?? 'prev/top-deals.json', null);

  const providers = [];
  if (env.BESTBUY_API_KEY) providers.push(['Best Buy', (id) => bestBuyListings(id, env.BESTBUY_API_KEY)]);
  if (env.SERPAPI_KEY) providers.push(['Walmart', (id) => walmartListings(id, env.SERPAPI_KEY)]);

  const errors = [];
  const deals = [];
  for (const [name, fetchListings] of providers) {
    for (const quote of quotes) {
      const id = String(quote.identifier ?? '').trim();
      if (!id || !(quote.tradeValue > 0)) continue;
      try {
        for (const listing of await fetchListings(id)) deals.push(evaluate(listing, quote, taxPercent));
      } catch (e) {
        errors.push(`${name}: ${e.message}`); // message never includes the request URL/key
      }
    }
  }
  if (!providers.length) errors.push('No API keys configured');

  const top = rank(deals);
  const feed = { generatedAt: iso(Date.now()), taxPercent, matched: deals.length,
                 errors: [...new Set(errors)], top };
  await mkdir(dirname(out), { recursive: true });
  await writeFile(out, JSON.stringify(feed, null, 2));
  console.log(`Matched ${deals.length} listings, ${top.length} profitable, ${feed.errors.length} errors`);

  // Skip notifications when a provider failed: its deals would look "new" next run.
  const fresh = newDeals(top, previous).filter((d) => d.roiPercent >= minRoi && d.netDifference >= minProfit);
  if (env.NTFY_TOPIC && fresh.length && !errors.length) await notify(env.NTFY_TOPIC, fresh);
  return feed;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) await main();
