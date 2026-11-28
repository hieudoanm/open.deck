import { useCallback, useEffect, useRef, useState } from "react";
import { useWakeLock } from "../hooks/useWakeLock";
import { fmtBytes } from "../lib/format";
import type {
  AppEntry,
  HelloMsg,
  PortEntry,
  StatsMsg,
  StatusMsg,
} from "../types";
import {
  PiArrowClockwise,
  PiCaretLeft,
  PiCaretRight,
  PiPower,
} from "react-icons/pi";
import { BOOKMARKS } from "../data/bookmarks";
import { cx, pageCls } from "../lib/ui";
import { AppsView } from "../components/AppsView";
import { BookmarksView, chunkBookmarks } from "../components/BookmarksView";
import { PortsView } from "../components/PortsView";
import { SystemView } from "../components/SystemView";
import { TimezonesPage } from "../widgets/TimezonesPage";
import { WidgetsPage } from "../widgets/WidgetsPage";
import { ControlPage } from "../widgets/ControlPage";

const BOOKMARK_PAGES = chunkBookmarks(BOOKMARKS);
const PAGE_COUNT = 6 + BOOKMARK_PAGES.length;

const NAV_BTN_CLS =
  "size-8 rounded-full border border-neutral bg-base-300 text-base-content text-base leading-none cursor-pointer shrink-0 inline-flex items-center justify-center p-0 active:bg-primary active:text-white active:border-primary";
const ICON_BTN_CLS =
  "size-8 rounded-full border border-neutral bg-base-300 text-primary text-base leading-none cursor-pointer shrink-0 inline-flex items-center justify-center p-0 active:bg-primary active:text-white active:border-primary";
const ICON_BTN_DANGER_CLS =
  "size-8 rounded-full border border-error/40 bg-base-300 text-error text-base leading-none cursor-pointer shrink-0 inline-flex items-center justify-center p-0 active:bg-error active:text-white active:border-error";
const WAKE_BADGE_CLS =
  "text-xs font-semibold px-2 py-0.5 rounded-full border border-neutral text-muted shrink-0";

export const DeckPage = ({
  host,
  port,
  token,
  onClose,
}: {
  host: string;
  port: string;
  token: string;
  onClose: () => void;
}) => {
  const base = `http://${host}:${port}`;
  const [statusText, setStatusText] = useState("connecting…");
  const [statusOk, setStatusOk] = useState(false);
  const [hello, setHello] = useState<HelloMsg | null>(null);
  const [stats, setStats] = useState<StatsMsg | null>(null);
  const [server, setServer] = useState<StatusMsg | null>(null);
  const [ports, setPorts] = useState<PortEntry[] | null>(null);
  const [apps, setApps] = useState<AppEntry[] | null>(null);
  const [page, setPage] = useState(0);
  const [confirming, setConfirming] = useState(false);
  const wake = useWakeLock();

  const wsRef = useRef<WebSocket | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const setDeckStatus = useCallback((text: string, ok: boolean) => {
    setStatusText(text);
    setStatusOk(ok);
  }, []);

  const pollHttp = useCallback(async () => {
    try {
      const r = await fetch(`${base}/status`);
      setServer(await r.json());
    } catch {
      /* ignore */
    }
    try {
      const r = await fetch(`${base}/ports`);
      setPorts(await r.json());
    } catch {
      /* ignore */
    }
    try {
      const r = await fetch(`${base}/apps`);
      const list: AppEntry[] = await r.json();
      setApps(list);
    } catch {
      /* ignore */
    }
  }, [base]);

  useEffect(() => {
    let closed = false;
    const url = `ws://${host}:${port}/ws?token=${encodeURIComponent(token)}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      ws.send(
        JSON.stringify({ type: "hello", name: "OpenDeck Web", version: 1 }),
      );
      setDeckStatus("connected", true);
      pollHttp();
      pollRef.current = setInterval(pollHttp, 5000);
    };

    ws.onmessage = (ev) => {
      if (typeof ev.data !== "string") return; // JPEG frames unused in widget mode
      let msg: Record<string, unknown>;
      try {
        msg = JSON.parse(ev.data);
      } catch {
        return;
      }
      if (msg.type === "hello") {
        setHello(msg as unknown as HelloMsg);
      } else if (msg.type === "error") {
        setDeckStatus(`error: ${msg.message}`, false);
      } else if (msg.type === "stats") {
        setStats(msg as unknown as StatsMsg);
        const s = msg as unknown as StatsMsg;
        setDeckStatus(
          `cpu ${s.cpu_percent != null ? s.cpu_percent.toFixed(0) + "%" : "?"} · ${fmtBytes(s.mem_used)}/${fmtBytes(s.mem_total)}`,
          true,
        );
      }
    };

    ws.onclose = () => {
      if (closed) return;
      setDeckStatus("disconnected", false);
      onClose();
    };
    ws.onerror = () => {
      setDeckStatus("connection failed", false);
    };

    return () => {
      closed = true;
      if (pollRef.current) clearInterval(pollRef.current);
      ws.close();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [host, port, token]);

  const goTo = useCallback((i: number) => {
    setPage(Math.max(0, Math.min(PAGE_COUNT - 1, i)));
  }, []);

  const startX = useRef<number | null>(null);

  const openUrl = useCallback(
    (url: string) => {
      fetch(`${base}/open?token=${encodeURIComponent(token)}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ url }),
      }).catch(() => {});
    },
    [base, token],
  );

  const wakeBadge =
    wake == null ? null : wake === "on" ? (
      <span
        className={cx(WAKE_BADGE_CLS, "text-success border-success/40")}
        title="screen wake lock"
      >
        awake
      </span>
    ) : (
      <span
        className={cx(WAKE_BADGE_CLS, "text-error border-error/40")}
        title="screen wake lock"
      >
        {wake === "unsupported" ? "no wake lock" : "sleeping"}
      </span>
    );

  return (
    <div className="relative flex h-full flex-col overflow-hidden pt-[calc(14px+env(safe-area-inset-top))] pr-[calc(14px+env(safe-area-inset-right))] pb-[calc(14px+env(safe-area-inset-bottom))] pl-[calc(14px+env(safe-area-inset-left))]">
      <div className="mb-3 flex items-center gap-2.5">
        <button
          className={NAV_BTN_CLS}
          aria-label="previous"
          title="previous"
          onClick={() => goTo(page - 1)}
        >
          <PiCaretLeft />
        </button>
        <span className="font-bold tracking-tight">OpenDeck</span>
        <span
          className={cx(
            "size-2.5 shrink-0 rounded-full",
            statusOk ? "bg-success" : "bg-error",
          )}
        />
        <span className="text-muted truncate text-xs">{statusText}</span>
        {wakeBadge}
        <span className="flex-1" />
        <button
          className={ICON_BTN_CLS}
          aria-label="refresh"
          title="refresh"
          onClick={pollHttp}
        >
          <PiArrowClockwise />
        </button>
        <button
          className={ICON_BTN_DANGER_CLS}
          aria-label="disconnect"
          title="disconnect"
          onClick={() => setConfirming(true)}
        >
          <PiPower />
        </button>
        <button
          className={NAV_BTN_CLS}
          aria-label="next"
          title="next"
          onClick={() => goTo(page + 1)}
        >
          <PiCaretRight />
        </button>
      </div>

      <div
        className="relative min-h-0 flex-1 touch-pan-y overflow-hidden"
        onPointerDown={(e) => {
          startX.current = e.clientX;
        }}
        onPointerUp={(e) => {
          if (startX.current == null) return;
          const dx = e.clientX - startX.current;
          startX.current = null;
          if (Math.abs(dx) > 50) goTo(page + (dx < 0 ? 1 : -1));
        }}
        onPointerCancel={() => {
          startX.current = null;
        }}
      >
        <div
          className="ease flex h-full transition-transform duration-300"
          style={{ transform: `translateX(-${page * 100}%)` }}
        >
          <section className={pageCls}>
            <ControlPage base={base} token={token} />
          </section>
          <section className={pageCls}>
            <SystemView stats={stats} hello={hello} server={server} />
          </section>
          <section className={pageCls}>
            <WidgetsPage />
          </section>
          <section className={pageCls}>
            <TimezonesPage />
          </section>
          <section className={pageCls}>
            <PortsView ports={ports} />
          </section>
          <section className={pageCls}>
            <AppsView apps={apps} />
          </section>
          {BOOKMARK_PAGES.map((items, i) => (
            <section className={pageCls} key={i}>
              <BookmarksView
                items={items}
                index={i}
                total={BOOKMARK_PAGES.length}
                onOpen={openUrl}
              />
            </section>
          ))}
        </div>
      </div>

      <div className="pointer-events-none absolute bottom-[calc(8px+env(safe-area-inset-bottom))] left-1/2 z-10 flex -translate-x-1/2 gap-2">
        {Array.from({ length: PAGE_COUNT }, (_, i) => (
          <button
            key={i}
            className={cx(
              "pointer-events-auto size-2 cursor-pointer rounded-full border-0 p-0",
              i === page ? "bg-primary" : "bg-white/25",
            )}
            onClick={() => goTo(i)}
            aria-label={`page ${i + 1}`}
          />
        ))}
      </div>

      {confirming && (
        <div
          className="modal modal-open bg-black/60 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          onClick={() => setConfirming(false)}
        >
          <div
            className="modal-box max-w-xs"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-base font-bold">Disconnect?</h3>
            <p className="text-muted mt-1 text-sm">
              The dashboard will close and return to the connect screen.
            </p>
            <div className="modal-action">
              <button
                className="btn btn-ghost btn-sm"
                onClick={() => setConfirming(false)}
              >
                Cancel
              </button>
              <button className="btn btn-error btn-sm" onClick={onClose}>
                Disconnect
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
