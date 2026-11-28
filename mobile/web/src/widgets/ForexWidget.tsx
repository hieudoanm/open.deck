import { useEffect, useState } from "react";
import { fetchVndRates, fmtVnd, FOREX_CODES } from "../lib/forex";
import { emptyCls, listCls, numCls, rowCls, rowNameCls } from "../lib/ui";
import { Widget } from "./Widget";
import { SkeletonRows } from "./Skeleton";

export const ForexWidget = () => {
  const [rates, setRates] = useState<Record<string, number> | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let live = true;
    const load = () =>
      fetchVndRates()
        .then((d) => {
          if (live) {
            setRates(d.rates);
            setFailed(false);
          }
        })
        .catch(() => {
          if (live) setFailed(true);
        });
    load();
    const t = setInterval(load, 30 * 60_000);
    return () => {
      live = false;
      clearInterval(t);
    };
  }, []);

  return (
    <Widget label="Forex · VND">
      {rates == null ? (
        failed ? (
          <div className={emptyCls}>rates unavailable</div>
        ) : (
          <div className={listCls}>
            <SkeletonRows count={FOREX_CODES.length} />
          </div>
        )
      ) : (
        <div className={listCls}>
          {FOREX_CODES.map((code) => {
            const v = rates[code];
            return (
              <div className={rowCls} key={code}>
                <b className={rowNameCls}>1 {code}</b>
                <span className={numCls}>
                  {v != null ? `${fmtVnd(v)} ₫` : "–"}
                </span>
              </div>
            );
          })}
        </div>
      )}
    </Widget>
  );
};
