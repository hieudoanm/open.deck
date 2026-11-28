import { useState } from "react";
import { cx } from "../lib/ui";

export const UnitPicker = ({
  units,
  value,
  onPick,
}: {
  units: { key: string; label: string }[];
  value: string;
  onPick: (key: string) => void;
}) => {
  const [open, setOpen] = useState(false);
  const current = units.find((u) => u.key === value);
  return (
    <div className="relative">
      <button
        className="bg-base-200 text-base-content/70 inline-flex items-center gap-1.5 rounded-lg px-3 py-2 text-sm"
        onClick={() => setOpen((o) => !o)}
      >
        {current?.label}
        <span className="text-[9px] opacity-50">▼</span>
      </button>
      {open && (
        <div className="bg-base-300 absolute top-full left-0 z-10 mt-1 max-h-48 overflow-y-auto rounded-lg p-1 shadow-lg">
          {units.map((u) => (
            <button
              key={u.key}
              className={cx(
                "block w-full rounded-md px-2 py-1.5 text-left text-[11px] whitespace-nowrap transition-colors",
                value === u.key
                  ? "bg-primary text-primary-content"
                  : "text-base-content/60 hover:bg-base-200",
              )}
              onClick={() => {
                onPick(u.key);
                setOpen(false);
              }}
            >
              {u.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
};
