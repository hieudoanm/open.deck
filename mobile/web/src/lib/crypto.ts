// CoinGecko public API — free, no key required (rate-limited; the widget
// caches responses client-side to stay well under the limit).

export interface Coin {
  symbol: string;
  name: string;
  price: number;
  change: number; // 24h %
}

interface Market {
  symbol: string;
  name: string;
  current_price: number;
  price_change_percentage_24h: number | null;
}

let cache: { at: number; coins: Coin[] } | null = null;

export const fetchCoins = async (limit = 8): Promise<Coin[]> => {
  if (cache && Date.now() - cache.at < 60_000) return cache.coins;
  const params = new URLSearchParams({
    vs_currency: "usd",
    order: "market_cap_desc",
    per_page: String(limit),
    page: "1",
    sparkline: "false",
    price_change_percentage: "24h",
  });
  const r = await fetch(
    `https://api.coingecko.com/api/v3/coins/markets?${params}`,
  );
  if (!r.ok) throw new Error(`coingecko ${r.status}`);
  const rows = (await r.json()) as Market[];
  const coins = rows.map((c) => ({
    symbol: c.symbol.toUpperCase(),
    name: c.name,
    price: c.current_price,
    change: c.price_change_percentage_24h ?? 0,
  }));
  if (coins.length === 0) throw new Error("no coins");
  cache = { at: Date.now(), coins };
  return coins;
};

export const fmtPrice = (p: number): string => {
  if (p >= 1000)
    return "$" + p.toLocaleString("en-US", { maximumFractionDigits: 0 });
  if (p >= 1)
    return "$" + p.toLocaleString("en-US", { maximumFractionDigits: 2 });
  return "$" + p.toPrecision(4);
};
