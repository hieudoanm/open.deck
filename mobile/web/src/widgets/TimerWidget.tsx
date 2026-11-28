import { useRef, useState } from "react";
import { PiPause, PiPlay, PiX } from "react-icons/pi";
import { useNow } from "../hooks/useNow";
import { fmtClock } from "../lib/format";
import {
  cdLineCls,
  cdLineLargeCls,
  cdWarnCls,
  cx,
  miniBtnCls,
  miniBtnDangerCls,
  miniBtnLargeCls,
  wtActionsCls,
  wtInputCls,
  wtInputLargeCls,
} from "../lib/ui";
import { Widget } from "./Widget";

// Accepts "m", "mm:ss" or "h:mm:ss"; a bare number is minutes.
const parseDur = (s: string): number | null => {
  const parts = s.trim().split(":");
  if (parts.length > 3 || parts.some((p) => !/^\d+$/.test(p))) return null;
  const nums = parts.map(Number);
  if (nums.slice(-2).some((n) => n >= 60)) return null;
  let secs = 0;
  for (const n of nums) secs = secs * 60 + n;
  return secs > 0 ? secs * 1000 : null;
};

export const TimerWidget = ({ large = false }: { large?: boolean }) => {
  const [input, setInput] = useState("5:00");
  const [left, setLeft] = useState<number | null>(null);
  const [endAt, setEndAt] = useState<number | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const now = useNow(100);
  const running = endAt != null;
  const remaining = running ? Math.max(0, endAt - now.getTime()) : left;

  const clearTimer = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  const begin = (dur: number) => {
    setLeft(dur);
    setEndAt(Date.now() + dur);
    clearTimer();
    timerRef.current = setTimeout(() => {
      setEndAt(null);
      setLeft(0);
    }, dur);
  };

  const toggle = () => {
    if (running) {
      clearTimer();
      setLeft(remaining);
      setEndAt(null);
    } else {
      const dur = left != null && left > 0 ? left : parseDur(input);
      if (dur != null) begin(dur);
    }
  };

  const reset = () => {
    clearTimer();
    setLeft(null);
    setEndAt(null);
  };

  const idle = !running && left == null;
  const done = !running && left === 0;
  const btnCls = large ? miniBtnLargeCls : miniBtnCls;

  return (
    <Widget label="Timer">
      {idle ? (
        <>
          <input
            className={large ? wtInputLargeCls : wtInputCls}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder="mm:ss"
            spellCheck={false}
            inputMode="numeric"
          />
          <div className={wtActionsCls}>
            <button
              className={btnCls}
              onClick={toggle}
              aria-label="start"
              title="start"
            >
              <PiPlay />
            </button>
          </div>
        </>
      ) : (
        <>
          <div
            className={cx(
              "tabular-nums",
              large ? cdLineLargeCls : cdLineCls,
              done || (remaining ?? 99e9) < 10_000 ? cdWarnCls : "",
            )}
          >
            {remaining != null ? fmtClock(remaining) : "--:--.-"}
          </div>
          <div className={wtActionsCls}>
            <button
              className={btnCls}
              onClick={toggle}
              aria-label={running ? "pause" : done ? "again" : "resume"}
              title={running ? "pause" : done ? "again" : "resume"}
            >
              {running ? <PiPause /> : <PiPlay />}
            </button>
            <button
              className={cx(btnCls, miniBtnDangerCls)}
              onClick={reset}
              aria-label="reset"
              title="reset"
            >
              <PiX />
            </button>
          </div>
        </>
      )}
    </Widget>
  );
};
