import { useEffect, useState } from "react";
import { fetchCoins, fmtPrice, type Coin } from "../lib/crypto";
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

export const CryptoWidget = () => {
  const [coins, setCoins] = useState<Coin[] | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let live = true;
    const load = () =>
      fetchCoins()
        .then((c) => {
          if (live) {
            setCoins(c);
            setErr(null);
          }
        })
        .catch((e: unknown) => {
          if (live) {
            setCoins(null);
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
    <Widget label="Crypto">
      {err ? (
        <div className={emptyCls}>{err}</div>
      ) : coins == null ? (
        <div className={listCls}>
          <SkeletonRows count={8} />
        </div>
      ) : (
        <div className={listCls}>
          {coins.slice(0, 8).map((c) => (
            <div className={rowCls} key={c.symbol}>
              <b className={rowNameCls}>{c.symbol}</b>
              <span className={numCls}>
                {fmtPrice(c.price)}{" "}
                <i className={c.change >= 0 ? upCls : downCls}>
                  {c.change >= 0 ? "+" : ""}
                  {c.change.toFixed(2)}%
                </i>
              </span>
            </div>
          ))}
        </div>
      )}
    </Widget>
  );
};
