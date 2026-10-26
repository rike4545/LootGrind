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

  document.getElementById("year").textContent = new Date().getFullYear();
  loadState();
  updateDates();
  renderRanking();
  calculate();
  loadAutomatedQuotes();
})();