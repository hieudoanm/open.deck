import type { AppEntry, PortEntry } from '../types';
import { fmtBytes } from '../lib/format';
import { Widget } from './Widget';

export function PortsPage({ ports }: { ports: PortEntry[] | null }) {
  return (
    <>
      <div className="page-title">Listening ports</div>
      <Widget className="flex-1 min-h-0">
        <div className="list">
          {ports == null ? (
            <div className="empty">loading…</div>
          ) : ports.length === 0 ? (
            <div className="empty">no listeners</div>
          ) : (
            ports.slice(0, 60).map((p, i) => (
              <div className="row" key={i}>
                <b>{p.process || '?'}</b>
                <span className="num">
                  {p.protocol} {p.address}:{p.port}
                </span>
              </div>
            ))
          )}
        </div>
      </Widget>
    </>
  );
}

export function AppsPage({ apps }: { apps: AppEntry[] | null }) {
  const top = apps
    ? [...apps].sort((a, b) => b.cpu_percent - a.cpu_percent).slice(0, 8)
    : null;
  return (
    <>
      <div className="page-title">Top processes</div>
      <Widget className="flex-1 min-h-0">
        <div className="list">
          {top == null ? (
            <div className="empty">loading…</div>
          ) : top.length === 0 ? (
            <div className="empty">no data</div>
          ) : (
            top.map((a) => (
              <div className="row" key={a.pid}>
                <b>{a.name}</b>
                <span className="num">
                  {a.cpu_percent.toFixed(0)}% · {fmtBytes(a.mem_bytes)}
                </span>
              </div>
            ))
          )}
        </div>
      </Widget>
    </>
  );
}
