import { useEffect, useRef } from "react";
import type { Dispatch, SetStateAction } from "react";
import { cx, pageTitleCls } from "../lib/ui";

interface GridBtn {
  label: string;
  append?: string;
  variant: "sci" | "mem" | "num" | "op" | "del" | "clear" | "eq";
  span?: number;
}

const ROWS: GridBtn[][] = [
  [
    { label: "sin(", variant: "sci" },
    { label: "cos(", variant: "sci" },
    { label: "tan(", variant: "sci" },
    { label: "AC", variant: "mem" },
    { label: "+/-", variant: "mem" },
    { label: "%", variant: "mem" },
    { label: "÷", variant: "op" },
    { label: "⌫", variant: "del" },
  ],
  [
    { label: "log(", variant: "sci" },
    { label: "ln(", variant: "sci" },
    { label: "√(", variant: "sci" },
    { label: "7", variant: "num" },
    { label: "8", variant: "num" },
    { label: "9", variant: "num" },
    { label: "×", variant: "op" },
    { label: "C", variant: "clear" },
  ],
  [
    { label: "π", variant: "sci" },
    { label: "e", variant: "sci" },
    { label: "^", variant: "sci" },
    { label: "4", variant: "num" },
    { label: "5", variant: "num" },
    { label: "6", variant: "num" },
    { label: "-", variant: "op" },
    { label: "", variant: "mem" },
  ],
  [
    { label: "x²", variant: "sci", append: "^2" },
    { label: "10^", variant: "sci", append: "10**" },
    { label: "n!", variant: "sci", append: "!" },
    { label: "1", variant: "num" },
    { label: "2", variant: "num" },
    { label: "3", variant: "num" },
    { label: "+", variant: "op" },
    { label: "=", variant: "eq" },
  ],
  [
    { label: "(", variant: "sci" },
    { label: ")", variant: "sci" },
    { label: "", variant: "mem" },
    { label: "0", variant: "num", span: 2 },
    { label: ".", variant: "num" },
    { label: "", variant: "mem" },
    { label: "", variant: "mem" },
    { label: "", variant: "mem" },
  ],
];

const BTN_CLS =
  "rounded-lg transition-colors active:opacity-70 min-h-9 text-sm";

const btnCls = (v: GridBtn["variant"]) => {
  switch (v) {
    case "sci":
      return cx(BTN_CLS, "bg-base-300 text-base-content/50 text-[10px]");
    case "mem":
      return cx(BTN_CLS, "bg-base-300 text-base-content/40 text-[10px]");
    case "eq":
      return cx(BTN_CLS, "bg-primary text-primary-content font-semibold");
    default:
      return cx(BTN_CLS, "bg-base-300 text-base-content");
  }
};

const calculate = (expression: string): string => {
  try {
    const sanitized = expression
      .replace(/×/g, "*")
      .replace(/÷/g, "/")
      .replace(/\^/g, "**")
      .replace(/π/g, "Math.PI")
      .replace(/e/g, "Math.E")
      .replace(/√\(/g, "Math.sqrt(")
      .replace(/log\(/g, "Math.log10(")
      .replace(/ln\(/g, "Math.log(")
      .replace(/sin\(([^)]+)\)/g, "Math.sin(($1) * Math.PI / 180)")
      .replace(/cos\(([^)]+)\)/g, "Math.cos(($1) * Math.PI / 180)")
      .replace(/tan\(([^)]+)\)/g, "Math.tan(($1) * Math.PI / 180)")
      .replace(/(\d+(?:\.\d+)?)!/g, "__fact($1)");
    return String(
      Function(
        `"use strict"; const __fact=n=>n<=1?1:n*__fact(n-1); return (${sanitized})`,
      )(),
    );
  } catch {
    return "Error";
  }
};

export const CalculatorView = ({
  expression,
  onExpression,
}: {
  expression: string;
  onExpression: Dispatch<SetStateAction<string>>;
}) => {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    containerRef.current?.focus();
  }, []);

  const append = (v: string) => onExpression((p) => p + v);
  const del = () => onExpression((p) => p.slice(0, -1));
  const clearExpr = () => onExpression("");
  const negate = () =>
    onExpression((p) => {
      const m = p.match(/(\d+\.?\d*)$/);
      return m ? p.slice(0, -m[1].length) + `(-${m[1]})` : p;
    });

  const onKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      onExpression((p) => calculate(p));
      return;
    }
    if (e.key === "Backspace") {
      del();
      return;
    }
    if (e.key === "Delete") {
      clearExpr();
      return;
    }
    if (/^[0-9+\-*/.%^()]$/.test(e.key)) append(e.key);
  };

  const gridClick = (b: GridBtn) => {
    if (b.label === "AC") {
      clearExpr();
      return;
    }
    if (b.label === "+/-") {
      negate();
      return;
    }
    if (b.variant === "eq") {
      onExpression((p) => calculate(p));
      return;
    }
    if (b.variant === "clear") {
      clearExpr();
      return;
    }
    if (b.variant === "del") {
      del();
      return;
    }
    append(b.append ?? b.label);
  };

  const isError = expression === "Error";
  const displayValue = expression || "0";

  return (
    <>
      <div className={pageTitleCls}>Calculator</div>
      <div className="flex min-h-0 flex-1 items-center justify-center overflow-y-auto">
        <div
          ref={containerRef}
          tabIndex={0}
          onKeyDown={onKeyDown}
          className="bg-base-200 border-neutral flex w-full max-w-md flex-col gap-2 rounded-2xl border p-3 outline-none"
        >
          <input
            type="text"
            value={displayValue}
            readOnly
            className={cx(
              "w-full bg-transparent text-right text-2xl font-light tracking-tight tabular-nums focus:outline-none",
              isError ? "text-error" : "text-base-content",
            )}
          />

          <div className="grid flex-1 grid-cols-8 content-center gap-1">
            {ROWS.map((row, rIdx) => (
              <div key={rIdx} className="contents">
                {row.map((b, bIdx) => {
                  if (b.variant === "mem" && b.label === "")
                    return <div key={bIdx} />;
                  return (
                    <button
                      key={bIdx}
                      className={cx(
                        btnCls(b.variant),
                        b.span === 2 && "col-span-2",
                      )}
                      onClick={() => gridClick(b)}
                    >
                      {b.label}
                    </button>
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      </div>
    </>
  );
};
