// Shared Tailwind class strings for the dashboard widgets.

export const cx = (...parts: Array<string | false | null | undefined>) =>
  parts.filter(Boolean).join(" ");

export const pageCls = "h-full shrink-0 grow-0 basis-full p-0.5 flex flex-col";

export const pageTitleCls = "text-xs uppercase tracking-widest text-muted mb-2";

export const gridCls =
  "grid flex-1 min-h-0 grid-cols-4 auto-rows-fr content-stretch gap-2";

export const split4GridCls =
  "grid flex-1 min-h-0 grid-cols-4 auto-rows-fr gap-2";

export const timersGridCls =
  "grid flex-1 min-h-0 grid-cols-4 gap-2 auto-rows-fr";

export const widgetCls =
  "bg-base-200 border border-neutral rounded-2xl min-h-0 flex flex-col justify-between gap-1 overflow-hidden px-4 py-3";

export const labelCls = "text-xs uppercase tracking-widest text-muted truncate";

export const valueCls =
  "text-lg font-bold tracking-tight mt-1 leading-tight truncate";

export const clockValueCls =
  "text-3xl font-bold tracking-tight mt-1 leading-tight truncate tabular-nums";

export const valueSmallCls = "text-xs font-medium text-muted";

export const subCls = "text-xs text-muted mt-1 truncate";

export const listCls =
  "mt-1 flex flex-col gap-0.5 flex-1 min-h-0 overflow-y-auto text-xs";

export const rowCls = "flex justify-between gap-2 py-0.5 text-muted";

export const rowNameCls = "text-base-content truncate font-medium";

export const numCls = "tabular-nums shrink-0";

export const emptyCls = "text-muted text-xs mt-2";

export const barCls =
  "h-1 rounded-full bg-base-300 mt-2 overflow-hidden shrink-0";

export const barFillCls =
  "block h-full rounded-full transition-all duration-500";

export const cdLinesCls = "flex flex-col leading-tight";

export const cdLineCls = "font-mono text-base tabular-nums text-accent";

export const cdLineLargeCls = "font-mono text-3xl tabular-nums text-accent";

export const cdWarnCls = "text-warning";

export const labrowCls = "inline-flex items-center gap-1 max-w-full";

export const wbtnCls =
  "bg-transparent border-0 text-muted cursor-pointer text-xs leading-none px-1 py-px inline-flex items-center hover:text-base-content";

export const wtInputCls =
  "w-full bg-base-300 border border-neutral rounded-lg text-base-content px-3 py-2 text-sm focus:outline-1 focus:outline-primary";

export const wtInputLargeCls =
  "w-full bg-base-300 border border-neutral rounded-lg text-base-content px-4 py-3 text-sm focus:outline-1 focus:outline-primary";

export const wtActionsCls = "flex flex-wrap gap-2 mt-auto";

export const miniBtnCls =
  "inline-flex items-center gap-1 bg-base-300 border border-neutral rounded-lg text-xs px-3 py-1 cursor-pointer hover:border-primary";

export const miniBtnLargeCls =
  "inline-flex items-center gap-1 bg-base-300 border border-neutral rounded-lg text-xs px-4 py-2 cursor-pointer hover:border-primary";

export const miniBtnDangerCls = "text-error";

export const upCls = "text-success not-italic";

export const downCls = "text-error not-italic";
