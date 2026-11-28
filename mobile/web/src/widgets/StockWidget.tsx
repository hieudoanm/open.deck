import { useEffect, useState } from "react";
import { fetchStocks, fmtStockPrice, type Stock } from "../lib/stocks";
import {
  downCls,
  emptyCls,
  listCls,
  numCls,
  rowCls,
  rowNameCls,
  upCls,
} from "../lib/ui";
import { Widget } from "./Widget";
import { SkeletonRows } from "./Skeleton";

export const StockWidget = () => {
  const [stocks, setStocks] = useState<Stock[] | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let live = true;
    const load = () =>
      fetchStocks()
        .then((s) => {
          if (live) {
            setStocks(s);
            setErr(null);
          }
        })
        .catch((e: unknown) => {
          if (live) {
            setStocks(null);
            setErr(e instanceof Error ? e.message : "fetch failed");
          }
        });
    load();
    const t = setInterval(load, 60_000);
    return () => {
      live = false;
      clearInterval(t);
    };
  }, []);

  return (
    <Widget label="Stocks · US">
      {err ? (
        <div className={emptyCls}>{err}</div>
      ) : stocks == null ? (
        <div className={listCls}>
          <SkeletonRows count={8} />
        </div>
      ) : (
        <div className={listCls}>
          {stocks.map((s) => (
            <div className={rowCls} key={s.symbol} title={s.name}>
              <b className={rowNameCls}>{s.symbol}</b>
              <span className={numCls}>
                {fmtStockPrice(s.price)}{" "}
                <i className={s.change >= 0 ? upCls : downCls}>
                  {s.change >= 0 ? "+" : ""}
                  {s.change.toFixed(2)}%
                </i>
              </span>
            </div>
          ))}
        </div>
      )}
    </Widget>
  );
};
