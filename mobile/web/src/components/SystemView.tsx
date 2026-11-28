import { fmtBytes, fmtRate, fmtUptime } from "../lib/format";
import {
  barCls,
  barFillCls,
  cx,
  gridCls,
  pageTitleCls,
  subCls,
  valueCls,
  valueSmallCls,
} from "../lib/ui";
import type { HelloMsg, StatsMsg, StatusMsg } from "../types";
import { Widget } from "../widgets/Widget";

const Bar = ({ pct }: { pct: number }) => {
  const fill = pct > 90 ? "bg-error" : pct > 70 ? "bg-warning" : "bg-primary";
  return (
    <div className={barCls}>
      <i
        className={cx(barFillCls, fill)}
        style={{ width: `${Math.min(100, Math.max(0, pct))}%` }}
      />
    </div>
  );
};

export const SystemView = ({
  stats,
  hello,
  server,
}: {
  stats: StatsMsg | null;
  hello: HelloMsg | null;
  server: StatusMsg | null;
}) => {
  const s = stats;
  return (
    <>
      <div className={pageTitleCls}>System</div>
      <div className={gridCls}>
        <Widget label="CPU">
          <div className={valueCls}>
            {s?.cpu_percent != null ? s.cpu_percent.toFixed(0) : "–"}
            <small className={valueSmallCls}>%</small>
          </div>
          <Bar pct={s?.cpu_percent ?? 0} />
        </Widget>

        <Widget label="Memory">
          <div className={valueCls}>
            {fmtBytes(s?.mem_used)}
            <small className={valueSmallCls}> / {fmtBytes(s?.mem_total)}</small>
          </div>
          <div className={subCls}>
            {s?.swap_total
              ? `swap ${fmtBytes(s.swap_used)} / ${fmtBytes(s.swap_total)}`
              : ""}
          </div>
          <Bar pct={s?.mem_total ? (s.mem_used / s.mem_total) * 100 : 0} />
        </Widget>

        <Widget label="Disk">
          <div className={valueCls}>
            {fmtBytes(s?.disk_used)}
            <small className={valueSmallCls}>
              {" "}
              / {fmtBytes(s?.disk_total)}
            </small>
          </div>
          <Bar pct={s?.disk_total ? (s.disk_used / s.disk_total) * 100 : 0} />
        </Widget>

        <Widget label="Network">
          <div className={valueCls}>{fmtRate(s?.net_rx_rate)}</div>
          <div className={subCls}>
            ↓ {fmtRate(s?.net_rx_rate)} · ↑ {fmtRate(s?.net_tx_rate)}
          </div>
        </Widget>

        <Widget label="Uptime">
          <div className={valueCls}>{fmtUptime(s?.uptime_secs)}</div>
          <div className={subCls}>
            {s?.net_interfaces?.length
              ? s.net_interfaces
                  .map((i) => i.name)
                  .slice(0, 4)
                  .join(" · ")
              : ""}
          </div>
        </Widget>

        <Widget label="Display">
          <div className={valueCls}>
            {hello
              ? `${hello.desktop_width}×${hello.desktop_height}`
              : server
                ? `${server.desktop_width}×${server.desktop_height}`
                : "–"}
          </div>
          <div className={subCls}>
            {hello
              ? `${hello.stream_width}×${hello.stream_height} stream · ${hello.fps}fps`
              : server
                ? `${server.fps} fps · ${server.clients} client(s)`
                : ""}
          </div>
        </Widget>

        {s?.battery_percent != null && (
          <Widget label="Battery">
            <div className={valueCls}>
              {Math.round(s.battery_percent)}
              <small className={valueSmallCls}>%</small>
            </div>
            <div className={subCls}>{s.battery_state || ""}</div>
          </Widget>
        )}
      </div>
    </>
  );
};
