import { useState } from "react";

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
  statusCls,
}: {
  creds: Creds;
  onChange: (c: Creds) => void;
  onConnect: () => void;
  status: string;
  statusCls: string;
}) {
  const [connecting, setConnecting] = useState(false);
  return (
    <div className="flex h-full items-center justify-center p-6">
      <div className="card bg-base-200 border-neutral w-full max-w-sm border p-7">
        <h1 className="m-0 mb-1 text-2xl font-bold tracking-tight">OpenDeck</h1>
        <div className="mb-5 text-sm text-[var(--muted)]">
          Your desktop, at a glance.
        </div>
        <div className="flex gap-2.5">
          <label className="fieldset flex-1">
            <span className="mb-1 block text-[11px] tracking-wider text-[var(--muted)] uppercase">
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
            <span className="mb-1 block text-[11px] tracking-wider text-[var(--muted)] uppercase">
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
          <span className="mb-1 block text-[11px] tracking-wider text-[var(--muted)] uppercase">
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
          className="btn btn-primary mt-1.5 w-full"
          disabled={connecting}
          onClick={() => {
            setConnecting(true);
            onConnect();
          }}
        >
          {connecting ? "Connecting…" : "Connect"}
        </button>
        <div
          className={`mt-3 min-h-[18px] text-center text-[12.5px] ${statusCls}`}
        >
          {status}
        </div>
        <div className="mt-4 text-center text-[11.5px] text-[var(--muted)]">
          Same Wi-Fi as your computer · free &amp; local
        </div>
      </div>
    </div>
  );
}
