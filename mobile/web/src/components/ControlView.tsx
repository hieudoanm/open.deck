import { useCallback, useEffect, useState } from "react";
import {
  PiBluetooth,
  PiBluetoothSlash,
  PiKeyboard,
  PiSpeakerHigh,
  PiSpeakerSlash,
  PiSunDim,
  PiWifiHigh,
  PiWifiSlash,
} from "react-icons/pi";
import type { IconType } from "react-icons";
import { cx, pageTitleCls } from "../lib/ui";
import { StopwatchWidget } from "./StopwatchWidget";
import { TimerWidget } from "./TimerWidget";
import { SkeletonTiles } from "./Skeleton";

interface Control {
  id: string;
  label: string;
  kind: "toggle" | "cycle" | "level";
  supported: boolean;
  on?: boolean | null;
  value?: number | null;
  detail?: string | null;
}

interface ControlsResponse {
  platform: string;
  controls: Control[];
}

const ICONS: Record<string, { on: IconType; off: IconType }> = {
  wifi: { on: PiWifiHigh, off: PiWifiSlash },
  sound: { on: PiSpeakerHigh, off: PiSpeakerSlash },
  bluetooth: { on: PiBluetooth, off: PiBluetoothSlash },
  keyboard: { on: PiKeyboard, off: PiKeyboard },
  brightness: { on: PiSunDim, off: PiSunDim },
};

const TILE_CLS =
  "bg-base-200 border border-neutral rounded-2xl p-4 flex flex-col items-start justify-center gap-1.5 cursor-pointer text-left text-base-content min-h-0 hover:border-primary active:bg-base-300 transition-colors disabled:cursor-default disabled:opacity-40 disabled:hover:border-neutral";

const stateText = (c: Control): string => {
  if (!c.supported) return c.detail ?? "unsupported";
  if (c.kind === "toggle") {
    const base = c.on ? "On" : "Off";
    return c.detail ? `${base} · ${c.detail}` : base;
  }
  if (c.kind === "cycle") return c.detail ?? "—";
  return `${c.value ?? "–"}%`;
};

const LEVEL_ICONS: Record<string, { on: IconType; off: IconType }> = {
  brightness: { on: PiSunDim, off: PiSunDim },
  sound: { on: PiSpeakerHigh, off: PiSpeakerSlash },
};

const LevelTile = ({
  control,
  onCommit,
}: {
  control: Control;
  onCommit: (v: number) => void;
}) => {
  const [local, setLocal] = useState<number | null>(null);
  const shown = local ?? control.value ?? 0;
  const icons = LEVEL_ICONS[control.id] ?? { on: PiSunDim, off: PiSunDim };
  const Icon = control.on === false ? icons.off : icons.on;
  const muted = control.on === false;
  return (
    <div className={cx(TILE_CLS, "cursor-default")}>
      <span className={cx("text-xl", muted ? "text-muted" : "text-primary")}>
        <Icon />
      </span>
      <span className="text-xs font-semibold">{control.label}</span>
      <input
        type="range"
        min={0}
        max={100}
        step={5}
        value={shown}
        disabled={!control.supported}
        aria-label={control.label.toLowerCase()}
        className="range range-xs accent-primary w-full"
        onChange={(e) => setLocal(Number(e.target.value))}
        onPointerUp={() => {
          if (local != null) onCommit(local);
          setLocal(null);
        }}
        onKeyUp={() => {
          if (local != null) onCommit(local);
          setLocal(null);
        }}
      />
      <span className="text-muted text-xs">
        {control.supported
          ? `${shown}%${muted ? " · muted" : ""}`
          : (control.detail ?? "unsupported")}
      </span>
    </div>
  );
};

export const ControlPage = ({
  base,
  token,
}: {
  base: string;
  token: string;
}) => {
  const [data, setData] = useState<ControlsResponse | null>(null);
  const [err, setErr] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      const r = await fetch(`${base}/controls`);
      if (!r.ok) throw new Error(String(r.status));
      setData(await r.json());
      setErr(null);
    } catch {
      setErr("unreachable");
    }
  }, [base]);

  useEffect(() => {
    const first = setTimeout(load, 0);
    const t = setInterval(load, 5000);
    return () => {
      clearTimeout(first);
      clearInterval(t);
    };
  }, [load]);

  const act = useCallback(
    async (id: string, action: string, value?: number) => {
      try {
        await fetch(`${base}/controls?token=${encodeURIComponent(token)}`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ id, action, value }),
        });
      } catch {
        /* surfaced on next poll */
      }
      load();
    },
    [base, token, load],
  );

  const controls = data?.controls ?? [];

  return (
    <>
      <div className={pageTitleCls}>Control · {data?.platform ?? "…"}</div>
      {err && <div className="text-error mb-1 text-xs">{err}</div>}
      <div className="grid min-h-0 flex-1 auto-rows-fr grid-cols-4 content-stretch gap-2">
        {controls.length === 0 && !err && <SkeletonTiles count={5} />}
        {controls.map((c) => {
          if (c.kind === "level") {
            return (
              <LevelTile
                key={c.id}
                control={c}
                onCommit={(v) => act(c.id, "set", v)}
              />
            );
          }
          const icons = ICONS[c.id] ?? { on: PiKeyboard, off: PiKeyboard };
          const Icon =
            c.kind === "toggle" && c.on === false ? icons.off : icons.on;
          return (
            <button
              key={c.id}
              className={TILE_CLS}
              disabled={!c.supported}
              onClick={() => act(c.id, c.kind === "cycle" ? "next" : "toggle")}
            >
              <span
                className={cx(
                  "text-xl",
                  c.supported && c.on !== false ? "text-primary" : "text-muted",
                )}
              >
                <Icon />
              </span>
              <span className="text-xs font-semibold">{c.label}</span>
              <span className="text-muted text-xs">{stateText(c)}</span>
            </button>
          );
        })}
        <StopwatchWidget />
        <TimerWidget />
      </div>
    </>
  );
};
