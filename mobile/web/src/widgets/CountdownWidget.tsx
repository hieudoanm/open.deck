import { useState } from "react";
import { PiCheck, PiPencilSimple, PiX } from "react-icons/pi";
import { useLocalStorage } from "../hooks/useLocalStorage";
import { useNow } from "../hooks/useNow";
import {
  cdLineCls,
  cdLinesCls,
  cdWarnCls,
  cx,
  labrowCls,
  miniBtnCls,
  miniBtnDangerCls,
  subCls,
  wtActionsCls,
  wtInputCls,
  wbtnCls,
} from "../lib/ui";
import { Widget } from "./Widget";

const toLocalInput = (iso: string): string => {
  const d = new Date(iso);
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`;
};

const pad = (n: number): string => {
  return String(n).padStart(2, "0");
};

const fmtDate = (d: Date): string => {
  return `${d.getFullYear()}.${pad(d.getMonth() + 1)}.${pad(d.getDate())}`;
};

const fmtStamp = (d: Date): string => {
  return `${fmtDate(d)} ${pad(d.getHours())}.${pad(d.getMinutes())}.${pad(d.getSeconds())}`;
};

interface CalParts {
  y: number;
  mo: number;
  d: number;
  h: number;
  mi: number;
  s: number;
}

// Calendar-aware breakdown of `later - earlier` (local time, DST ignored).
const calParts = (later: Date, earlier: Date): CalParts => {
  let s = later.getSeconds() - earlier.getSeconds();
  let mi = later.getMinutes() - earlier.getMinutes();
  let h = later.getHours() - earlier.getHours();
  let d = later.getDate() - earlier.getDate();
  let mo = later.getMonth() - earlier.getMonth();
  let y = later.getFullYear() - earlier.getFullYear();
  if (s < 0) {
    s += 60;
    mi--;
  }
  if (mi < 0) {
    mi += 60;
    h--;
  }
  if (h < 0) {
    h += 24;
    d--;
  }
  if (d < 0) {
    mo--;
    d += new Date(later.getFullYear(), later.getMonth(), 0).getDate();
  }
  if (mo < 0) {
    y--;
    mo += 12;
  }
  return { y, mo, d, h, mi, s };
};

const fmtBig = (p: CalParts): string => {
  return `${pad(p.y)}Y ${pad(p.mo)}M ${pad(p.d)}D`;
};

const fmtSmall = (p: CalParts): string => {
  return `${pad(p.h)}h ${pad(p.mi)}m ${pad(p.s)}s`;
};

export const CountdownWidget = () => {
  const [target, setTarget] = useLocalStorage<string | null>(
    "opendeck.countdown",
    null,
  );
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState("");
  const now = useNow(1000);

  const ms = target ? new Date(target).getTime() - now.getTime() : null;
  const targetDate = target ? new Date(target) : null;

  const openEditor = () => {
    setDraft(target ? toLocalInput(target) : "");
    setEditing(true);
  };

  if (editing) {
    return (
      <Widget
        label={
          <span className={labrowCls}>
            Countdown
            <button
              className={wbtnCls}
              aria-label="cancel"
              onClick={() => setEditing(false)}
            >
              <PiX />
            </button>
          </span>
        }
      >
        <input
          type="datetime-local"
          className={wtInputCls}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
        />
        <div className={wtActionsCls}>
          <button
            className={miniBtnCls}
            onClick={() => {
              if (draft) setTarget(new Date(draft).toISOString());
              setEditing(false);
            }}
          >
            <PiCheck /> Set
          </button>
          {target && (
            <button
              className={cx(miniBtnCls, miniBtnDangerCls)}
              onClick={() => {
                setTarget(null);
                setEditing(false);
              }}
            >
              Clear
            </button>
          )}
        </div>
      </Widget>
    );
  }

  return (
    <Widget
      label={
        <span className={labrowCls}>
          Countdown
          <button
            className={wbtnCls}
            aria-label="edit countdown"
            onClick={openEditor}
          >
            <PiPencilSimple />
          </button>
        </span>
      }
    >
      {(() => {
        if (ms == null || !targetDate) {
          return <div className={cdLineCls}>--.--.--</div>;
        }
        const elapsed = ms < 0;
        const p = calParts(
          elapsed ? now : targetDate,
          elapsed ? targetDate : now,
        );
        const warn = ms < 24 * 3600_000 ? cdWarnCls : "";
        return (
          <div className={cdLinesCls}>
            <div className={cx(cdLineCls, warn)}>
              {elapsed ? "+" : ""}
              {fmtBig(p)}
            </div>
            <div className={cx(cdLineCls, warn)}>{fmtSmall(p)}</div>
          </div>
        );
      })()}
      <div className={subCls}>
        {targetDate
          ? `${ms! >= 0 ? "until" : "elapsed since"} ${fmtStamp(targetDate)}`
          : "tap to set a date"}
      </div>
    </Widget>
  );
};
