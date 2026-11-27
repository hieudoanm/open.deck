import { useState } from "react";
import type { Bookmark } from "../data/bookmarks";

export const BOOKMARKS_PER_PAGE = 8;

export function chunkBookmarks(
  items: Bookmark[],
  size = BOOKMARKS_PER_PAGE,
): Bookmark[][] {
  const out: Bookmark[][] = [];
  for (let i = 0; i < items.length; i += size)
    out.push(items.slice(i, i + size));
  return out;
}

export function BookmarksPage({
  items,
  index,
  total,
  onOpen,
}: {
  items: Bookmark[];
  index: number;
  total: number;
  onOpen: (url: string) => void;
}) {
  const [opened, setOpened] = useState<string | null>(null);
  return (
    <>
      <div className="page-title">
        Bookmarks {index + 1}/{total}
      </div>
      <div className="bm-grid">
        {items.map((b) => {
          const Icon = b.icon;
          const isOpen = opened === b.href;
          return (
            <button
              key={b.href}
              className={`bm-tile${isOpen ? "opened" : ""}`}
              onClick={() => {
                onOpen(b.href);
                setOpened(b.href);
                setTimeout(() => setOpened(null), 1200);
              }}
            >
              <Icon className="bm-icon" />
              <span className="bm-label">{b.label}</span>
              <span className="bm-desc">
                {b.badge ? `${b.badge} · ` : ""}
                {b.description}
              </span>
            </button>
          );
        })}
      </div>
    </>
  );
}
