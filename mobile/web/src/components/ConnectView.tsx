import { useState } from 'react';

export interface Creds {
  host: string;
  port: string;
  token: string;
}

export function ConnectView({
  creds,
  onChange,
  onConnect,
  status,
  statusCls
}: {
  creds: Creds;
  onChange: (c: Creds) => void;
  onConnect: () => void;
  status: string;
  statusCls: string;
}) {
  const [connecting, setConnecting] = useState(false);
  return (
    <div className="h-full flex items-center justify-center p-6">
      <div className="card w-full max-w-sm bg-base-200 border border-neutral p-7">
        <h1 className="text-2xl font-bold tracking-tight m-0 mb-1">OpenDeck</h1>
        <div className="text-sm text-[var(--muted)] mb-5">
          Your desktop, at a glance.
        </div>
        <div className="flex gap-2.5">
          <label className="fieldset flex-1">
            <span className="text-[11px] uppercase tracking-wider text-[var(--muted)] mb-1 block">
              Host
            </span>
            <input
              className="input input-bordered w-full"
              value={creds.host}
              placeholder="192.168.1.10"
              spellCheck={false}
              onChange={(e) => onChange({ ...creds, host: e.target.value })}
            />
          </label>
          <label className="fieldset w-24">
            <span className="text-[11px] uppercase tracking-wider text-[var(--muted)] mb-1 block">
              Port
            </span>
            <input
              className="input input-bordered w-full"
              value={creds.port}
              inputMode="numeric"
              spellCheck={false}
              onChange={(e) => onChange({ ...creds, port: e.target.value })}
            />
          </label>
        </div>
        <label className="fieldset mt-3">
          <span className="text-[11px] uppercase tracking-wider text-[var(--muted)] mb-1 block">
            Pairing token
          </span>
          <input
            className="input input-bordered w-full"
            value={creds.token}
            placeholder="printed by open-deck-server"
            spellCheck={false}
            onChange={(e) => onChange({ ...creds, token: e.target.value })}
          />
        </label>
        <button
          className="btn btn-primary w-full mt-1.5"
          disabled={connecting}
          onClick={() => {
            setConnecting(true);
            onConnect();
          }}
        >
          {connecting ? 'Connecting…' : 'Connect'}
        </button>
        <div
          className={`text-[12.5px] text-center mt-3 min-h-[18px] ${statusCls}`}
        >
          {status}
        </div>
        <div className="text-[11.5px] text-[var(--muted)] text-center mt-4">
          Same Wi-Fi as your computer · free &amp; local
        </div>
      </div>
    </div>
  );
}
