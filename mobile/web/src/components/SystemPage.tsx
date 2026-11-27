import { useNow } from "../hooks/useNow";
import { fmtBytes, fmtRate, fmtUptime } from "../lib/format";
import type { HelloMsg, StatsMsg, StatusMsg } from "../types";
import { Widget } from "./Widget";

function Bar({ pct }: { pct: number }) {
  const cls = pct > 90 ? "hot" : pct > 70 ? "warm" : "";
  return (
    <div className="bar">
      <i
        className={cls}
        style={{ width: `${Math.min(100, Math.max(0, pct))}%` }}
      />
    </div>
  );
}

export function SystemPage({
  stats,
  hello,
  server,
}: {
  stats: StatsMsg | null;
  hello: HelloMsg | null;
  server: StatusMsg | null;
}) {
  const now = useNow();
  const s = stats;
  return (
    <>
      <div className="page-title">System</div>
      <div className="grid">
        <Widget label="Time">
          <div className="value clock-value">
            {now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
          </div>
          <div className="sub">
            {now.toLocaleDateString([], {
              weekday: "short",
              month: "short",
              day: "numeric",
            })}
          </div>
        </Widget>

        <Widget label="CPU">
          <div className="value">
            {s?.cpu_percent != null ? s.cpu_percent.toFixed(0) : "–"}
            <small>%</small>
          </div>
          <Bar pct={s?.cpu_percent ?? 0} />
        </Widget>

        <Widget label="Memory">
          <div className="value">
            {fmtBytes(s?.mem_used)}
            <small> / {fmtBytes(s?.mem_total)}</small>
          </div>
          <div className="sub">
            {s?.swap_total
              ? `swap ${fmtBytes(s.swap_used)} / ${fmtBytes(s.swap_total)}`
              : ""}
          </div>
          <Bar pct={s?.mem_total ? (s.mem_used / s.mem_total) * 100 : 0} />
        </Widget>

        <Widget label="Disk">
          <div className="value">
            {fmtBytes(s?.disk_used)}
            <small> / {fmtBytes(s?.disk_total)}</small>
          </div>
          <Bar pct={s?.disk_total ? (s.disk_used / s.disk_total) * 100 : 0} />
        </Widget>

        <Widget label="Network">
          <div className="value">{fmtRate(s?.net_rx_rate)}</div>
          <div className="sub">
            ↓ {fmtRate(s?.net_rx_rate)} · ↑ {fmtRate(s?.net_tx_rate)}
          </div>
        </Widget>

        <Widget label="Uptime">
          <div className="value">{fmtUptime(s?.uptime_secs)}</div>
          <div className="sub">
            {s?.net_interfaces?.length
              ? s.net_interfaces
                  .map((i) => i.name)
                  .slice(0, 4)
                  .join(" · ")
              : ""}
          </div>
        </Widget>

        <Widget label="Display">
          <div className="value">
            {hello
              ? `${hello.desktop_width}×${hello.desktop_height}`
              : server
                ? `${server.desktop_width}×${server.desktop_height}`
                : "–"}
          </div>
          <div className="sub">
            {hello
              ? `${hello.stream_width}×${hello.stream_height} stream · ${hello.fps}fps`
              : server
                ? `${server.fps} fps · ${server.clients} client(s)`
                : ""}
          </div>
        </Widget>

        {s?.battery_percent != null && (
          <Widget label="Battery">
            <div className="value">
              {Math.round(s.battery_percent)}
              <small>%</small>
            </div>
            <div className="sub">{s.battery_state || ""}</div>
          </Widget>
        )}
      </div>
    </>
  );
}
