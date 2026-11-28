// Forex rates with VND as base via open.er-api.com (free, no key, ~daily).

const CODES = [
  "USD",
  "EUR",
  "JPY",
  "GBP",
  "CNY",
  "KRW",
  "SGD",
  "THB",
  "AUD",
  "CAD",
  "CHF",
  "RUB",
] as const;

export const FOREX_CODES = CODES;

interface Payload {
  result?: string;
  rates?: Record<string, number>;
  time_last_update_utc?: string;
}

let cache: { at: number; rates: Record<string, number> } | null = null;

/// Returns `code -> VND per 1 unit of code` (e.g. USD → ~25,400).
export const fetchVndRates = async (): Promise<{
  rates: Record<string, number>;
  updatedUtc: string;
}> => {
  if (cache && Date.now() - cache.at < 30 * 60_000) {
    return { rates: cache.rates, updatedUtc: "" };
  }
  const r = await fetch("https://open.er-api.com/v6/latest/VND");
  if (!r.ok) throw new Error(`er-api ${r.status}`);
  const j = (await r.json()) as Payload;
  if (j.result !== "success" || !j.rates) throw new Error("bad er-api payload");
  const out: Record<string, number> = {};
  for (const code of CODES) {
    const perVnd = j.rates[code];
    if (perVnd && perVnd > 0) out[code] = 1 / perVnd;
  }
  cache = { at: Date.now(), rates: out };
  return { rates: out, updatedUtc: j.time_last_update_utc ?? "" };
};

export const fmtVnd = (v: number): string => {
  const digits = v >= 1000 ? 0 : v >= 10 ? 1 : 3;
  return v.toLocaleString("en-US", {
    minimumFractionDigits: 0,
    maximumFractionDigits: digits,
  });
};
