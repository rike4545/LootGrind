(() => {
  const money = value => (value < 0 ? "−$" : value > 0 ? "+$" : "$") + Math.abs(value).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const fields = ["price", "tax", "costs", "payout"].map(id => document.getElementById(id));
  const netOutput = document.getElementById("net-result");
  const roiOutput = document.getElementById("roi-result");
  const note = document.getElementById("calc-note");

  function calculate() {
    const [price, taxPercent, costs, payout] = fields.map(field => Math.max(0, Number(field.value) || 0));
    const totalCost = price + price * taxPercent / 100 + costs;
    const net = payout - totalCost;
    const roi = totalCost > 0 ? net / totalCost * 100 : 0;
    netOutput.textContent = money(net);
    netOutput.classList.toggle("negative", net < 0);
    roiOutput.textContent = (roi > 0 ? "+" : "") + roi.toFixed(1) + "%";
    roiOutput.classList.toggle("negative", roi < 0);
    const type = document.querySelector('input[name="payoutType"]:checked').value;
    note.textContent = type === "credit"
      ? "Store-credit estimate only. Credit is not cash and may have redemption limits. Confirm the quote, eligibility, and all costs before buying."
      : "Cash estimate assumes the quoted payout is received in full. It excludes any costs not entered above and is not a guarantee of profit.";
  }
  fields.forEach(field => field.addEventListener("input", calculate));
  document.querySelectorAll('input[name="payoutType"]').forEach(input => input.addEventListener("change", calculate));

  // Manual opportunity tracker. Quotes stay in this browser; nothing is uploaded.
  const storageKey = "lootgrind.manualTradeQuotes.v1";
  const rows = Array.from(document.querySelectorAll("#scanner-rows tr[data-product]"));
  const taxField = document.getElementById("scanner-tax");
  const ranking = document.getElementById("ranking-results");
  const saveStatus = document.getElementById("save-status");
  const feedStatus = document.getElementById("feed-status");
  function setFeedStatus(message, state) {
    if (!feedStatus) return;
    feedStatus.textContent = message;
    feedStatus.dataset.state = state || "info";
  }
  const currency = value => (value < 0 ? "−$" : "$") + Math.abs(value).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  const number = input => input.value.trim() === "" ? null : Number(input.value);
  const fieldsFor = row => Object.fromEntries(Array.from(row.querySelectorAll("[data-field]")).map(input => [input.dataset.field, input]));

  function readState() {
    const products = {};
    rows.forEach(row => {
      const f = fieldsFor(row);
      products[row.dataset.product] = {
        retail: f.retail.value,
        quote: f.quote.value,
        quoteSource: row.dataset.quoteSource || "",
        payout: f.payout.value,
        costs: f.costs.value,
        checkedAt: row.dataset.checkedAt || ""
      };
    });
    return { tax: taxField.value, products };
  }
  function saveState() {
    try {
      localStorage.setItem(storageKey, JSON.stringify(readState()));
      saveStatus.textContent = "Saved locally in this browser";
    } catch (_) {
      saveStatus.textContent = "Browser storage unavailable; export CSV to keep a copy";
    }
  }
  function loadState() {
    try {
      const saved = JSON.parse(localStorage.getItem(storageKey) || "null");
      if (!saved) return;
      if (typeof saved.tax === "string") taxField.value = saved.tax;
      rows.forEach(row => {
        const savedProduct = saved.products && saved.products[row.dataset.product];
        if (!savedProduct) return;
        const f = fieldsFor(row);
        ["retail", "quote", "payout", "costs"].forEach(key => {
          if (typeof savedProduct[key] === "string") f[key].value = savedProduct[key];
        });
        row.dataset.checkedAt = savedProduct.checkedAt || "";
        row.dataset.quoteSource = savedProduct.quoteSource || (savedProduct.quote ? "manual" : "");
      });
    } catch (_) {
      saveStatus.textContent = "Couldn't read saved quotes; enter them again or import no data";
    }
  }
  function quoteAgeLabel(dateString) {
    if (!dateString) return "Not entered";
    const date = new Date(dateString);
    if (Number.isNaN(date.getTime())) return "Date unknown";
    const days = Math.floor((Date.now() - date.getTime()) / 86400000);
    const label = date.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
    return days > 7 ? label + " · stale" : label;
  }
  function renderRanking() {
    const taxRaw = number(taxField);
    const tax = taxRaw === null ? 0 : Math.min(30, Math.max(0, taxRaw));
    const opportunities = [];
    rows.forEach(row => {
      const f = fieldsFor(row);
      const retail = number(f.retail);
      const quote = number(f.quote);
      if (retail === null || quote === null || retail <= 0 || quote <= 0) return;
      const costsRaw = number(f.costs);
      const costs = costsRaw === null ? 0 : Math.max(0, costsRaw);
      const totalCost = retail * (1 + tax / 100) + costs;
      const net = quote - totalCost;
      const roi = totalCost > 0 ? net / totalCost * 100 : 0;
      const checkedAt = row.dataset.checkedAt || "";
      const ageDays = checkedAt ? Math.floor((Date.now() - new Date(checkedAt).getTime()) / 86400000) : null;
      opportunities.push({ name: row.dataset.product, net, roi, payout: f.payout.value, totalCost, checkedAt, ageDays });
    });
    opportunities.sort((a, b) => b.net - a.net);
    ranking.replaceChildren();
    if (!opportunities.length) {
      const p = document.createElement("p");
      p.className = "empty-ranking";
      p.textContent = "Enter a retail price and trade-in quote for at least one product to see your ranking.";
      ranking.appendChild(p);
      return;
    }
    opportunities.forEach((item, index) => {
      const article = document.createElement("article");
      article.className = "ranking-item";
      const left = document.createElement("div");
      left.className = "ranking-product";
      const title = document.createElement("strong");
      title.textContent = (index + 1) + ". " + item.name;
      const detail = document.createElement("small");
      detail.textContent = (item.payout === "credit" ? "Store credit · not cash" : "Cash quote") + " · Cost basis " + currency(item.totalCost) + (item.ageDays === null ? " · quote date not recorded" : item.ageDays > 7 ? " · quote may be stale" : " · checked " + quoteAgeLabel(item.checkedAt));
      left.append(title, detail);
      const right = document.createElement("div");
      right.className = "ranking-values";
      const net = document.createElement("strong");
      net.className = item.net >= 0 ? "ranking-positive" : "ranking-negative";
      net.textContent = (item.net > 0 ? "+" : "") + currency(item.net);
      const roi = document.createElement("small");
      roi.textContent = (item.roi > 0 ? "+" : "") + item.roi.toFixed(1) + "% ROI";
      right.append(net, roi);
      article.append(left, right);
      ranking.appendChild(article);
    });
  }
  function updateDates() {
    rows.forEach(row => {
      const dateCell = row.querySelector(".checked-date");
      dateCell.textContent = quoteAgeLabel(row.dataset.checkedAt || "");
      dateCell.classList.toggle("stale-quote", Boolean(row.dataset.checkedAt) && Math.floor((Date.now() - new Date(row.dataset.checkedAt).getTime()) / 86400000) > 7);
    });
  }
  function onTrackerChange(event) {
    const row = event.target.closest("tr[data-product]");
    if (row && event.target.dataset.field === "quote") {
      row.dataset.quoteSource = "manual";
      if (event.target.value.trim() !== "") row.dataset.checkedAt = new Date().toISOString();
    }
    saveState();
    updateDates();
    renderRanking();
  }
  rows.forEach(row => row.querySelectorAll("[data-field]").forEach(input => input.addEventListener("input", onTrackerChange)));
  taxField.addEventListener("input", () => { saveState(); renderRanking(); });
  document.getElementById("export-quotes").addEventListener("click", () => {
    const header = ["Product", "Retail price", "Trade-in quote", "Payout type", "Extra costs", "Sales tax percent", "Quote checked at", "Estimated net", "Estimated ROI percent"];
    const taxRaw = number(taxField);
    const tax = taxRaw === null ? 0 : Math.min(30, Math.max(0, taxRaw));
    const csvRows = [header];
    rows.forEach(row => {
      const f = fieldsFor(row);
      const retail = number(f.retail);
      const quote = number(f.quote);
      const costsRaw = number(f.costs);
      const costs = costsRaw === null ? 0 : Math.max(0, costsRaw);
      const total = retail !== null && retail > 0 ? retail * (1 + tax / 100) + costs : null;
      const net = total !== null && quote !== null && quote > 0 ? quote - total : "";
      const roi = total > 0 && net !== "" ? (net / total * 100).toFixed(2) : "";
      csvRows.push([row.dataset.product, f.retail.value, f.quote.value, f.payout.value, f.costs.value, taxField.value, row.dataset.checkedAt || "", net === "" ? "" : net.toFixed(2), roi]);
    });
    const csv = csvRows.map(line => line.map(value => '"' + String(value).replace(/"/g, '""') + '"').join(",")).join("\r\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = url;
    link.download = "lootgrind-trade-in-quotes.csv";
    link.click();
    URL.revokeObjectURL(url);
  });
  document.getElementById("clear-quotes").addEventListener("click", () => {
    if (!window.confirm("Clear all saved LootGrind quote entries in this browser?")) return;
    taxField.value = "";
    rows.forEach(row => {
      Object.values(fieldsFor(row)).forEach(input => { input.value = input.dataset.field === "payout" ? "cash" : ""; });
      row.dataset.checkedAt = "";
      row.dataset.quoteSource = "";
    });
    try { localStorage.removeItem(storageKey); } catch (_) {}
    saveStatus.textContent = "Saved quotes cleared";
    updateDates();
    renderRanking();
  });

  // Load the latest published snapshot from the scheduled authorized-feed workflow.
  // Manual quotes remain in control once the user edits a quote field.
  async function loadAutomatedQuotes() {
    const productByIdentifier = {
      "heg-001": "Nintendo Switch OLED",
      "cfi-2015": "PlayStation 5 Slim",
      "cfi-zct1w": "DualSense Wireless Controller",
      "cfi-y1001": "PlayStation Portal",
      "1914": "Xbox Wireless Controller"
    };
    try {
      const response = await fetch("data/trade-in-quotes.json", { cache: "no-store" });
      if (!response.ok) throw new Error("Quote snapshot unavailable");
      const snapshot = await response.json();
      if (!Array.isArray(snapshot.quotes) || snapshot.quotes.length === 0) {
        if (snapshot.provider === "not-configured") {
          saveStatus.textContent = "Authorized quote feed not configured";
          setFeedStatus("Automatic trade-in quotes are not active yet. Add an authorized feed to enable scheduled updates; manual quotes still work.", "warning");
        } else {
          setFeedStatus("The latest snapshot contains no verified trade-in quotes. Check the authorized provider feed or enter quotes manually.", "warning");
        }
        return;
      }
      let applied = 0;
      snapshot.quotes.forEach(quote => {
        const identifier = String(quote.identifier || "").trim().toLowerCase();
        const productName = productByIdentifier[identifier];
        if (!productName || !(Number(quote.tradeValue) > 0)) return;
        const row = rows.find(candidate => candidate.dataset.product === productName);
        if (!row || row.dataset.quoteSource === "manual") return;
        const f = fieldsFor(row);
        f.quote.value = Number(quote.tradeValue).toFixed(2);
        f.payout.value = quote.payoutType === "Store Credit" ? "credit" : "cash";
        row.dataset.checkedAt = quote.quotedAt || snapshot.generatedAt || "";
        row.dataset.quoteSource = "feed";
        applied += 1;
      });
      if (applied) {
        saveState();
        updateDates();
        renderRanking();
        const updatedAt = snapshot.generatedAt ? new Date(snapshot.generatedAt).toLocaleString() : "timestamp unavailable";
        saveStatus.textContent = "Updated " + applied + " quote(s) from authorized feed · " + updatedAt;
        setFeedStatus("Authorized feed active · " + applied + " quote(s) loaded · snapshot generated " + updatedAt + ". Retail prices and extra costs are still entered by you.", "success");
      } else {
        setFeedStatus("An authorized quote snapshot was found, but all matching products are manually overridden or unsupported. Clear a manual quote to allow feed updates.", "info");
      }
    } catch (_) {
      saveStatus.textContent = "Automatic quote snapshot unavailable; manual tracking still works";
      setFeedStatus("Couldn't load the published quote snapshot. Manual tracking is available; automatic quotes require a working authorized feed and site deployment.", "warning");
    }
  }

  // Magic card tracker. Prices are stored locally; automated values require a licensed feed.
  const magicStorageKey = "lootgrind.magicCards.v1";
  const magicRows = document.getElementById("magic-rows");
  const magicFeedStatus = document.getElementById("magic-feed-status");
  const magicSaveStatus = document.getElementById("magic-save-status");
  const setMagicStatus = (message, state = "info") => {
    magicFeedStatus.textContent = message;
    magicFeedStatus.dataset.state = state;
  };
  const safeNumber = value => value !== "" && value !== null && Number.isFinite(Number(value)) && Number(value) >= 0 ? Number(value) : null;
  const magicKey = item => [item.name, item.set, item.condition, item.finish].map(v => String(v || "").trim().toLowerCase()).join("|");
  let magicCards = [];
  try { magicCards = JSON.parse(localStorage.getItem(magicStorageKey) || "[]"); if (!Array.isArray(magicCards)) magicCards = []; } catch (_) { magicCards = []; }

  const magicSources = [
    { key: "tcgplayerMarket", label: "TCGplayer", url: "https://www.tcgplayer.com/categories/trading-and-collectible-card-games/magic-the-gathering/price-guides" },
    { key: "pricechartingPrice", label: "PriceCharting", url: "https://www.pricecharting.com/category/magic-cards" },
    { key: "cardConduitBuylist", label: "Card Conduit", url: "https://cardconduit.com/card-price-check" },
    { key: "gamestopTradeValue", label: "GameStop", url: "https://www.gamestop.com/trade/" }
  ];
  function saveMagic() {
    try { localStorage.setItem(magicStorageKey, JSON.stringify(magicCards)); magicSaveStatus.textContent = "Cards saved locally in this browser"; }
    catch (_) { magicSaveStatus.textContent = "Browser storage unavailable; export a CSV backup"; }
  }
  function renderMagic() {
    magicRows.replaceChildren();
    if (!magicCards.length) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.colSpan = 7;
      cell.className = "magic-empty";
      cell.textContent = "Add a Magic card above to track the exact printing, condition, and finish.";
      row.appendChild(cell); magicRows.appendChild(row); return;
    }
    magicCards.forEach((card, index) => {
      const row = document.createElement("tr");
      const detail = document.createElement("td");
      const title = document.createElement("strong"); title.textContent = card.name;
      const meta = document.createElement("small"); meta.textContent = card.set + " · " + card.condition + " · " + card.finish;
      detail.append(title, meta); row.appendChild(detail);
      magicSources.forEach(source => {
        const cell = document.createElement("td");
        const input = document.createElement("input");
        input.className = "magic-value"; input.type = "number"; input.min = "0"; input.step = ".01";
        input.placeholder = "Not checked"; input.value = card[source.key] ?? "";
        input.setAttribute("aria-label", source.label + " value for " + card.name);
        input.addEventListener("change", () => {
          const value = input.value.trim();
          card[source.key] = value === "" ? "" : String(Math.max(0, Number(value) || 0));
          card[source.key + "CheckedAt"] = value === "" ? "" : new Date().toISOString();
          saveMagic(); renderMagic();
        });
        cell.appendChild(input);
        const checked = card[source.key + "CheckedAt"];
        if (checked) { const small = document.createElement("small"); small.textContent = "Checked " + new Date(checked).toLocaleDateString(); cell.appendChild(small); }
        row.appendChild(cell);
      });
      const spreadCell = document.createElement("td"); spreadCell.className = "magic-spread";
      const marketValues = [safeNumber(card.tcgplayerMarket), safeNumber(card.pricechartingPrice)].filter(v => v !== null);
      const bestMarket = marketValues.length ? Math.max(...marketValues) : null;
      const buylist = safeNumber(card.cardConduitBuylist);
      const gs = safeNumber(card.gamestopTradeValue);
      const text = bestMarket === null ? "Add market prices" : "Market ref: " + currency(bestMarket) + (buylist === null ? "" : "\nBuylist gap: " + currency(buylist - bestMarket)) + (gs === null ? "" : "\nGameStop gap: " + currency(gs - bestMarket));
      spreadCell.textContent = text; spreadCell.style.whiteSpace = "pre-line"; row.appendChild(spreadCell);
      const linksCell = document.createElement("td"); linksCell.className = "magic-source-links";
      const q = encodeURIComponent(card.name + " " + card.set);
      const links = [
        ["Search TCGplayer ↗", "https://www.tcgplayer.com/search/magic/product?q=" + q],
        ["Search PriceCharting ↗", "https://www.pricecharting.com/search-products?type=prices&q=" + q],
        ["Card Conduit checker ↗", "https://cardconduit.com/card-price-check"],
        ["GameStop Trade Center ↗", "https://www.gamestop.com/trade/"]
      ];
      links.forEach(([label, href]) => { const a = document.createElement("a"); a.href = href; a.target = "_blank"; a.rel = "noreferrer"; a.textContent = label; linksCell.appendChild(a); });
      const remove = document.createElement("button"); remove.type = "button"; remove.className = "magic-remove"; remove.textContent = "Remove";
      remove.addEventListener("click", () => { magicCards.splice(index, 1); saveMagic(); renderMagic(); });
      linksCell.appendChild(remove); row.appendChild(linksCell);
      magicRows.appendChild(row);
    });
  }
  document.getElementById("magic-add-form").addEventListener("submit", event => {
    event.preventDefault();
    const card = {
      name: document.getElementById("magic-name").value.trim(),
      set: document.getElementById("magic-set").value.trim(),
      condition: document.getElementById("magic-condition").value,
      finish: document.getElementById("magic-finish").value,
      tcgplayerMarket: "", pricechartingPrice: "", cardConduitBuylist: "", gamestopTradeValue: ""
    };
    if (!card.name || !card.set) return;
    const key = magicKey(card);
    if (magicCards.some(item => magicKey(item) === key)) { setMagicStatus("That exact card, set, condition, and finish is already tracked.", "warning"); return; }
    magicCards.push(card); saveMagic(); renderMagic(); event.target.reset();
    document.getElementById("magic-condition").value = "Near Mint";
    document.getElementById("magic-finish").value = "nonfoil";
  });
  document.getElementById("magic-clear").addEventListener("click", () => {
    if (!window.confirm("Clear all Magic cards saved in this browser?")) return;
    magicCards = []; saveMagic(); renderMagic();
  });
  document.getElementById("magic-export").addEventListener("click", () => {
    const headers = ["Card", "Set/printing", "Condition", "Finish", "TCGplayer market", "PriceCharting", "Card Conduit buylist", "GameStop trade-in"];
    const values = magicCards.map(card => [card.name, card.set, card.condition, card.finish, card.tcgplayerMarket, card.pricechartingPrice, card.cardConduitBuylist, card.gamestopTradeValue]);
    const csv = [headers, ...values].map(line => line.map(value => '"' + String(value ?? "").replace(/"/g, '""') + '"').join(",")).join("\r\n");
    const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8;" }));
    const link = document.createElement("a"); link.href = url; link.download = "lootgrind-magic-card-prices.csv"; link.click(); URL.revokeObjectURL(url);
  });
  async function loadMagicSnapshot() {
    try {
      const response = await fetch("data/magic-card-prices.json", { cache: "no-store" });
      if (!response.ok) throw new Error("snapshot unavailable");
      const snapshot = await response.json();
      if (!Array.isArray(snapshot.cards) || !snapshot.cards.length) {
        setMagicStatus("Daily publishing is set up, but no authorized Magic pricing feed is configured yet. Add MAGIC_CARD_PRICE_FEED_URL and MAGIC_CARD_PRICE_FEED_KEY in GitHub repository Actions secrets to publish verified prices.", "warning");
        return;
      }
      let updated = 0;
      snapshot.cards.forEach(quote => {
        if (!quote || !quote.name || !quote.set || !quote.condition || !quote.finish) return;
        const key = magicKey(quote);
        let card = magicCards.find(item => magicKey(item) === key);
        if (!card) {
          card = {
            name: String(quote.name), set: String(quote.set),
            condition: String(quote.condition), finish: String(quote.finish),
            tcgplayerMarket: "", pricechartingPrice: "", cardConduitBuylist: "", gamestopTradeValue: ""
          };
          magicCards.push(card);
        }
        ["tcgplayerMarket", "pricechartingPrice", "cardConduitBuylist", "gamestopTradeValue"].forEach(field => {
          if (safeNumber(quote[field]) !== null) {
            card[field] = String(quote[field]);
            card[field + "CheckedAt"] = quote.checkedAt || snapshot.generatedAt || "";
            updated++;
          }
        });
        card.gamestopStatus = quote.gamestopStatus || (safeNumber(quote.gamestopTradeValue) !== null ? "verified" : "unverified");
        card.grade = quote.grade || "";
        card.collectorNumber = quote.collectorNumber || "";
        card.sourceUrls = quote.sourceUrls || {};
      });
      if (updated) {
        saveMagic();
        renderMagic();
        setMagicStatus("Loaded " + updated + " verified source value(s) across " + snapshot.cards.length + " published card(s). Snapshot generated " + (snapshot.generatedAt ? new Date(snapshot.generatedAt).toLocaleString() : "at an unknown time") + ". GameStop values marked unverified are not offers.", "success");
      } else {
        setMagicStatus("The published snapshot contains " + snapshot.cards.length + " card(s), but no numeric price values matched the expected schema.", "warning");
      }
    } catch (_) {
      setMagicStatus("Could not load the published Magic price snapshot. The daily workflow is ready, but a licensed feed must be configured before prices can update.", "warning");
    }
  }
  renderMagic();
  loadMagicSnapshot();

  document.getElementById("year").textContent = new Date().getFullYear();
  loadState();
  updateDates();
  renderRanking();
  calculate();
  loadAutomatedQuotes();
})();