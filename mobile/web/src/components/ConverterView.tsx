import { useState } from "react";
import { converterCategories, romanToArabic } from "../lib/convert";
import { cx, pageTitleCls } from "../lib/ui";
import { UnitPicker } from "./UnitPicker";

const formatNumber = (n: number): string => {
  if (!isFinite(n)) return String(n);
  if (Number.isInteger(n) && Math.abs(n) < 1e15)
    return n.toLocaleString("en-US");
  const s = n.toFixed(6).replace(/\.?0+$/, "");
  if (s.length > 16) return n.toExponential(4);
  return s;
};

export const ConverterView = ({ expression }: { expression: string }) => {
  const [category, setCategory] = useState("length");
  const [fromUnit, setFromUnit] = useState(
    converterCategories.length.defaultFrom,
  );
  const [toUnit, setToUnit] = useState(converterCategories.length.defaultTo);

  const config = converterCategories[category];
  const inputNum = parseFloat(expression) || 0;
  const isRomanFrom = category === "roman" && fromUnit === "roman";
  const result = isRomanFrom
    ? (() => {
        const n = romanToArabic(expression);
        return n == null ? "Error" : String(n);
      })()
    : config.convert(inputNum, fromUnit, toUnit);
  const numResult = parseFloat(result);
  const formattedResult = isNaN(numResult) ? result : formatNumber(numResult);

  const swap = () => {
    const u = fromUnit;
    setFromUnit(toUnit);
    setToUnit(u);
  };

  const switchCategory = (key: string) => {
    setCategory(key);
    const c = converterCategories[key];
    setFromUnit(c.defaultFrom);
    setToUnit(c.defaultTo);
  };

  return (
    <>
      <div className={pageTitleCls}>Converter</div>
      <div className="flex min-h-0 flex-1 items-center justify-center overflow-y-auto">
        <div className="bg-base-200 border-neutral flex w-full max-w-lg flex-col gap-3 rounded-2xl border p-4">
          <div className="flex flex-wrap gap-1">
            {Object.entries(converterCategories).map(([key, c]) => (
              <button
                key={key}
                onClick={() => switchCategory(key)}
                className={cx(
                  "rounded-full px-2.5 py-1 text-[10px] transition-colors",
                  category === key
                    ? "bg-primary text-primary-content"
                    : "bg-base-300 text-base-content/50 hover:text-base-content/80",
                )}
              >
                {c.label}
              </button>
            ))}
          </div>

          <div className="bg-base-300 flex items-center justify-between rounded-lg px-3 py-2.5">
            <UnitPicker
              units={config.units}
              value={fromUnit}
              onPick={setFromUnit}
            />
            <span className="text-base-content text-2xl font-light tabular-nums">
              {isRomanFrom ? expression || "0" : formatNumber(inputNum)}
            </span>
          </div>

          <button
            onClick={swap}
            className="bg-base-300 text-base-content/50 hover:bg-base-200 mx-auto flex size-7 items-center justify-center rounded-full text-sm transition-colors"
          >
            ⇅
          </button>

          <div className="bg-base-300 flex items-center justify-between rounded-lg px-3 py-2.5">
            <UnitPicker
              units={config.units}
              value={toUnit}
              onPick={setToUnit}
            />
            <span
              className={cx(
                "text-2xl font-light tabular-nums",
                result === "Error" ? "text-error" : "text-base-content",
              )}
            >
              {formattedResult}
            </span>
          </div>
        </div>
      </div>
    </>
  );
};
