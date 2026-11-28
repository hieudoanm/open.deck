import { cx } from "../lib/ui";

export const SkeletonBar = ({ className }: { className?: string }) => (
  <div className={cx("bg-base-300 h-3 animate-pulse rounded", className)} />
);

/** Placeholder rows matching the `rowCls` list layout (name + value). */
export const SkeletonRows = ({ count = 6 }: { count?: number }) => (
  <>
    {Array.from({ length: count }, (_, i) => (
      <div className="flex justify-between gap-2 py-0.5" key={i}>
        <SkeletonBar className="w-1/3" />
        <SkeletonBar
          className={cx("shrink-0", i % 3 === 0 ? "w-1/4" : "w-1/5")}
        />
      </div>
    ))}
  </>
);

/** Placeholder tiles matching the Control page grid. */
export const SkeletonTiles = ({ count = 5 }: { count?: number }) => (
  <>
    {Array.from({ length: count }, (_, i) => (
      <div
        key={i}
        className="bg-base-200 border-neutral flex animate-pulse flex-col gap-2 rounded-2xl border p-4"
      >
        <div className="bg-base-300 size-6 rounded" />
        <SkeletonBar className="w-2/3" />
        <SkeletonBar className="w-1/2" />
      </div>
    ))}
  </>
);
