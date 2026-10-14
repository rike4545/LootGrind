import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluate, rank, newDeals, bestBuyListings, walmartListings } from './scan.mjs';

const quote = (tradeValue, identifier = '123') =>
  ({ identifier, tradeValue, payoutType: 'Cash', source: 'GameStop', quotedAt: new Date().toISOString() });
const listing = (price, sku = '1', retailer = 'Best Buy') =>
  ({ sku, name: `Item ${sku}`, retailer, price, url: null, isExactMatch: true });

test('evaluate applies tax and computes ROI', () => {
  const d = evaluate(listing(100), quote(150), 10);
  assert.equal(d.totalCost, 110);
  assert.equal(d.netDifference, 40);
  assert.equal(d.roiPercent, 36.36);
});

test('rank keeps only profitable deals, best ROI first, max 5', () => {
  const deals = [1, 2, 3, 4, 5, 6, 7].map((i) => evaluate(listing(100, String(i)), quote(100 + i * 10), 0))
    .concat(evaluate(listing(100, 'loss'), quote(50), 0));
  const top = rank(deals);
  assert.equal(top.length, 5);
  assert.equal(top[0].rank, 1);
  assert.equal(top[0].name, 'Item 7');
  assert.ok(top.every((d) => d.netDifference > 0));
});

test('stale quotes are flagged', () => {
  const old = { ...quote(150), quotedAt: new Date(Date.now() - 8 * 86400000).toISOString() };
  assert.equal(evaluate(listing(100), old, 0).quoteStale, true);
});

test('newDeals returns only deals missing from the previous feed', () => {
  const a = evaluate(listing(100, 'a'), quote(150), 0);
  const b = evaluate(listing(100, 'b'), quote(150), 0);
  assert.deepEqual(newDeals([a, b], { top: [a] }).map((d) => d.id), [b.id]);
  assert.equal(newDeals([a], null).length, 1);
});

test('providers parse responses and reject unsafe identifiers', async () => {
  const bb = async () => ({ ok: true, json: async () => ({ products: [
    { sku: 1, name: 'A', salePrice: 10, url: 'u', onlineAvailability: true },
    { sku: 2, name: 'B', salePrice: 0 }] }) });
  assert.equal((await bestBuyListings('123', 'k', bb)).length, 1);
  const wm = async () => ({ ok: true, json: async () => ({ organic_results: [
    { us_item_id: '9', title: 'W', upc: '123', primary_offer: { offer_price: 20 } },
    { us_item_id: '8', title: 'X', primary_offer: {} }] }) });
  const w = await walmartListings('123', 'k', wm);
  assert.equal(w.length, 1);
  assert.equal(w[0].isExactMatch, true);
  assert.deepEqual(await bestBuyListings('a)&b', 'k', bb), []);
  await assert.rejects(bestBuyListings('123', 'k', async () => ({ ok: false, status: 403 })), /HTTP 403/);
});
