import type { AppEntry } from "../types";
import { fmtBytes } from "../lib/format";
import {
  emptyCls,
  listCls,
  numCls,
  pageTitleCls,
  rowCls,
  rowNameCls,
} from "../lib/ui";
import { Widget } from "../widgets/Widget";
import { SkeletonRows } from "../widgets/Skeleton";

export const AppsView = ({ apps }: { apps: AppEntry[] | null }) => {
  const top = apps
    ? [...apps].sort((a, b) => b.cpu_percent - a.cpu_percent).slice(0, 8)
    : null;
  return (
    <>
      <div className={pageTitleCls}>Top processes</div>
      <Widget className="min-h-0 flex-1">
        <div className={listCls}>
          {top == null ? (
            <SkeletonRows count={8} />
          ) : top.length === 0 ? (
            <div className={emptyCls}>no data</div>
          ) : (
            top.map((a) => (
              <div className={rowCls} key={a.pid}>
                <b className={rowNameCls}>{a.name}</b>
                <span className={numCls}>
                  {a.cpu_percent.toFixed(0)}% · {fmtBytes(a.mem_bytes)}
                </span>
              </div>
            ))
          )}
        </div>
      </Widget>
    </>
  );
};
