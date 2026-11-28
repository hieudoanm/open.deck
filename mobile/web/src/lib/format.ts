export const fmtBytes = (n: number | null | undefined): string => {
  if (n == null || isNaN(n)) return "–";
  const u = ["B", "KB", "MB", "GB", "TB"];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(i ? 1 : 0)} ${u[i]}`;
};

export const fmtRate = (n: number | null | undefined): string => {
  return fmtBytes(n) + "/s";
};

export const fmtClock = (ms: number): string => {
  const t = Math.max(0, Math.floor(ms));
  const h = Math.floor(t / 3600000);
  const m = Math.floor((t % 3600000) / 60000);
  const s = Math.floor((t % 60000) / 1000);
  const tenths = Math.floor((t % 1000) / 100);
  const p = (n: number) => String(n).padStart(2, "0");
  return h > 0 ? `${h}:${p(m)}:${p(s)}.${tenths}` : `${p(m)}:${p(s)}.${tenths}`;
};

export const fmtUptime = (s: number | null | undefined): string => {
  if (s == null) return "–";
  const d = Math.floor(s / 86400);
  const h = Math.floor((s % 86400) / 3600);
  const m = Math.floor((s % 3600) / 60);
  if (d > 0) return `${d}d ${h}h`;
  if (h > 0) return `${h}h ${m}m`;
  return `${m}m`;
};
