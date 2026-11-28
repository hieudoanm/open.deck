import { useState } from "react";
import type { Bookmark } from "../data/bookmarks";
import { cx, pageTitleCls, split4GridCls } from "../lib/ui";

export const BOOKMARKS_PER_PAGE = 12;

export const chunkBookmarks = (
  items: Bookmark[],
  size = BOOKMARKS_PER_PAGE,
): Bookmark[][] => {
  const out: Bookmark[][] = [];
  for (let i = 0; i < items.length; i += size)
    out.push(items.slice(i, i + size));
  return out;
};

export const BookmarksView = ({
  items,
  index,
  total,
  onOpen,
}: {
  items: Bookmark[];
  index: number;
  total: number;
  onOpen: (url: string) => void;
}) => {
  const [opened, setOpened] = useState<string | null>(null);
  return (
    <>
      <div className={pageTitleCls}>
        Bookmarks {index + 1}/{total}
      </div>
      <div className={split4GridCls}>
        {items.map((b) => {
          const Icon = b.icon;
          const isOpen = opened === b.href;
          return (
            <button
              key={b.href}
              className={cx(
                "bg-base-200 text-base-content flex min-h-0 cursor-pointer flex-col items-start justify-center gap-1 overflow-hidden rounded-xl border px-4 py-3 text-left transition-colors",
                isOpen
                  ? "border-success"
                  : "border-neutral active:border-primary active:bg-base-300",
              )}
              onClick={() => {
                onOpen(b.href);
                setOpened(b.href);
                setTimeout(() => setOpened(null), 1200);
              }}
            >
              <Icon className="text-primary shrink-0 text-lg" />
              <span className="max-w-full truncate text-sm font-semibold">
                {b.label}
              </span>
              <span className="text-muted max-w-full truncate text-xs">
                {b.badge ? `${b.badge} · ` : ""}
                {b.description}
              </span>
            </button>
          );
        })}
      </div>
    </>
  );
};
