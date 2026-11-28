import type { PortEntry } from "../types";
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

export const PortsView = ({ ports }: { ports: PortEntry[] | null }) => {
  return (
    <>
      <div className={pageTitleCls}>Listening ports</div>
      <Widget className="min-h-0 flex-1">
        <div className={listCls}>
          {ports == null ? (
            <SkeletonRows />
          ) : ports.length === 0 ? (
            <div className={emptyCls}>no listeners</div>
          ) : (
            ports.slice(0, 60).map((p, i) => (
              <div className={rowCls} key={i}>
                <b className={rowNameCls}>{p.process || "?"}</b>
                <span className={numCls}>
                  {p.protocol} {p.address}:{p.port}
                </span>
              </div>
            ))
          )}
        </div>
      </Widget>
    </>
  );
};
