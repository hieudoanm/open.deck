// US stock quotes via CNBC's public quote endpoint — free, no key, CORS-open.
// Quotes may be delayed ~15min outside market hours.

export interface Stock {
  symbol: string;
  name: string;
  price: number;
  change: number; // 24h / day %
}

const TICKERS = [
  "AAPL",
  "MSFT",
  "NVDA",
  "AMZN",
  "GOOGL",
  "META",
  "TSLA",
  "JPM",
] as const;

interface Quote {
  symbol: string;
  shortName?: string;
  last?: string;
  change_pct?: string;
}

let cache: { at: number; stocks: Stock[] } | null = null;

export const fetchStocks = async (): Promise<Stock[]> => {
  if (cache && Date.now() - cache.at < 5 * 60_000) return cache.stocks;
  const url =
    "https://quote.cnbc.com/quote-html-webservice/restQuote/symbolType/symbol" +
    `?symbols=${TICKERS.join("|")}&requestMethod=itv&noform=1&partnerId=2&fund=1&exthrs=1&output=json`;
  const r = await fetch(url);
  if (!r.ok) throw new Error(`cnbc ${r.status}`);
  const j = (await r.json()) as {
    FormattedQuoteResult?: { FormattedQuote?: Quote[] };
  };
  const rows = j.FormattedQuoteResult?.FormattedQuote ?? [];
  const stocks = rows
    .map((q) => ({
      symbol: q.symbol,
      name: q.shortName ?? q.symbol,
      price: parseFloat(q.last ?? ""),
      change: parseFloat((q.change_pct ?? "").replace("%", "")),
    }))
    .filter((s) => Number.isFinite(s.price));
  if (stocks.length === 0) throw new Error("no quotes");
  cache = { at: Date.now(), stocks };
  return stocks;
};

export const fmtStockPrice = (p: number): string => {
  return "$" + p.toLocaleString("en-US", { maximumFractionDigits: 2 });
};
