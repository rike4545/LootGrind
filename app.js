(() => {
  const fields = ["price", "tax", "costs", "payout"].map(id => document.getElementById(id));
  const netOutput = document.getElementById("net-result");
  const roiOutput = document.getElementById("roi-result");
  const note = document.getElementById("calc-note");
  const money = value => (value < 0 ? "−$" : value > 0 ? "+$" : "$") + Math.abs(value).toLocaleString("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
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
  document.getElementById("year").textContent = new Date().getFullYear();
  calculate();
})();