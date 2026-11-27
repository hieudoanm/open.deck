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
import { BOOKMARKS } from "../data/bookmarks";
import { AppsPage, PortsPage } from "./Pages";
import { SystemPage } from "./SystemPage";
import { BookmarksPage, chunkBookmarks } from "./BookmarksPage";

const BOOKMARK_PAGES = chunkBookmarks(BOOKMARKS);
const PAGE_COUNT = 3 + BOOKMARK_PAGES.length;

export function DeckView({
  host,
  port,
  token,
  onClose,
}: {
  host: string;
  port: string;
  token: string;
  onClose: () => void;
}) {
  const base = `http://${host}:${port}`;
  const [statusText, setStatusText] = useState("connecting…");
  const [statusOk, setStatusOk] = useState(false);
  const [hello, setHello] = useState<HelloMsg | null>(null);
  const [stats, setStats] = useState<StatsMsg | null>(null);
  const [server, setServer] = useState<StatusMsg | null>(null);
  const [ports, setPorts] = useState<PortEntry[] | null>(null);
  const [apps, setApps] = useState<AppEntry[] | null>(null);
  const [page, setPage] = useState(0);
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
      <span className="wake-badge on" title="screen wake lock">
        awake
      </span>
    ) : (
      <span className="wake-badge off" title="screen wake lock">
        {wake === "unsupported" ? "no wake lock" : "sleeping"}
      </span>
    );

  return (
    <div className="deck-view">
      <div className="topbar">
        <button
          className="navbtn"
          aria-label="previous"
          onClick={() => goTo(page - 1)}
        >
          ‹
        </button>
        <span className="title">OpenDeck</span>
        <span className={`status-dot${statusOk ? "" : "err"}`} />
        <span className="status-text">{statusText}</span>
        {wakeBadge}
        <span style={{ flex: 1 }} />
        <button className="btn btn-sm" onClick={pollHttp}>
          Refresh
        </button>
        <button className="btn btn-error btn-sm" onClick={onClose}>
          Disconnect
        </button>
        <button
          className="navbtn"
          aria-label="next"
          onClick={() => goTo(page + 1)}
        >
          ›
        </button>
      </div>

      <div
        className="pager"
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
          className="track"
          style={{ transform: `translateX(-${page * 100}%)` }}
        >
          <section className="page">
            <SystemPage stats={stats} hello={hello} server={server} />
          </section>
          <section className="page">
            <PortsPage ports={ports} />
          </section>
          <section className="page">
            <AppsPage apps={apps} />
          </section>
          {BOOKMARK_PAGES.map((items, i) => (
            <section className="page" key={i}>
              <BookmarksPage
                items={items}
                index={i}
                total={BOOKMARK_PAGES.length}
                onOpen={openUrl}
              />
            </section>
          ))}
        </div>
      </div>

      <div className="dots">
        {Array.from({ length: PAGE_COUNT }, (_, i) => (
          <button
            key={i}
            className={i === page ? "on" : ""}
            onClick={() => goTo(i)}
            aria-label={`page ${i + 1}`}
          />
        ))}
      </div>
    </div>
  );
}
