// Unit-converter categories for CalculatorView — ported from omni
// packages/web calculator/convert.ts. Base/Roman conversion is implemented
// locally (omni used @lodashx/ts).

const convertWithRates =
  (rates: Record<string, number>) =>
  (fromAmount: number, fromUnit: string, toUnit: string): number =>
    parseFloat(((fromAmount * rates[toUnit]) / rates[fromUnit]).toFixed(6));

const BASE_DIGITS = "0123456789ABCDEF";

const toBaseDigits = (n: number, base: number): string => {
  const v = Math.round(n);
  if (v === 0) return "0";
  const neg = v < 0 ? "-" : "";
  let x = Math.abs(v);
  let s = "";
  while (x > 0) {
    s = BASE_DIGITS[x % base] + s;
    x = Math.floor(x / base);
  }
  return neg + s;
};

const convertBase = (amount: number, from: string, to: string): string => {
  // The typed digits are read in `from` base, then rendered in `to` base.
  const dec = parseInt(String(Math.round(amount)), parseInt(from, 10));
  return isNaN(dec) ? "Error" : toBaseDigits(dec, parseInt(to, 10));
};

const ROMAN_NUMERALS: ReadonlyArray<readonly [number, string]> = [
  [1000, "M"],
  [900, "CM"],
  [500, "D"],
  [400, "CD"],
  [100, "C"],
  [90, "XC"],
  [50, "L"],
  [40, "XL"],
  [10, "X"],
  [9, "IX"],
  [5, "V"],
  [4, "IV"],
  [1, "I"],
];

export const arabicToRoman = (n: number): string => {
  if (!Number.isFinite(n) || n <= 0 || n >= 4000) return "Error";
  let x = Math.round(n);
  let s = "";
  for (const [v, r] of ROMAN_NUMERALS) {
    while (x >= v) {
      s += r;
      x -= v;
    }
  }
  return s;
};

const ROMAN_VALUES: Record<string, number> = {
  I: 1,
  V: 5,
  X: 10,
  L: 50,
  C: 100,
  D: 500,
  M: 1000,
};

export const romanToArabic = (s: string): number | null => {
  const t = s.trim().toUpperCase();
  if (!t) return null;
  let total = 0;
  let prev = 0;
  for (let i = t.length - 1; i >= 0; i--) {
    const v = ROMAN_VALUES[t[i]];
    if (v == null) return null;
    total += v < prev ? -v : v;
    prev = Math.max(prev, v);
  }
  return total > 0 ? total : null;
};

export type AngleUnit = "degrees" | "radians";

export const convertAngle = (
  fromAmount: number,
  fromUnit: AngleUnit,
  toUnit: AngleUnit,
): number => {
  let degreesValue: number;
  if (fromUnit === "degrees") degreesValue = fromAmount;
  else if (fromUnit === "radians") degreesValue = fromAmount * (180 / Math.PI);
  else degreesValue = fromAmount;
  if (toUnit === "degrees") return parseFloat(degreesValue.toFixed(5));
  else if (toUnit === "radians")
    return parseFloat((degreesValue * (Math.PI / 180)).toFixed(5));
  return parseFloat(degreesValue.toFixed(5));
};

export type DataUnit =
  "bit" | "kilobyte" | "megabyte" | "gigabyte" | "terabyte";

export const dataRates: Record<DataUnit, number> = {
  bit: 1,
  kilobyte: 8 * 1024,
  megabyte: 8 * 1024 * 1024,
  gigabyte: 8 * 1024 * 1024 * 1024,
  terabyte: 8 * 1024 * 1024 * 1024 * 1024,
};

export type LengthUnit =
  "yard" | "foot" | "inch" | "centimeter" | "meter" | "kilometer";

export const lengthRates: Record<LengthUnit, number> = {
  yard: 1,
  foot: 3,
  inch: 36,
  centimeter: 91.44,
  meter: 0.9144,
  kilometer: 0.0009144,
};

export type WeightUnit =
  "ton" | "pound" | "ounce" | "kilogram" | "gram" | "milligram";

export const weightRates: Record<WeightUnit, number> = {
  ton: 1,
  pound: 2_000,
  ounce: 32_000,
  kilogram: 907.18474,
  gram: 907184.74,
  milligram: 907184740,
};

export type TemperatureUnit = "celsius" | "fahrenheit" | "kelvin";

export const convertTemperature = (
  fromAmount: number,
  fromUnit: TemperatureUnit,
  toUnit: TemperatureUnit,
): number => {
  let celsiusValue: number;
  if (fromUnit === "celsius") celsiusValue = fromAmount;
  else if (fromUnit === "fahrenheit")
    celsiusValue = ((fromAmount - 32) * 5) / 9;
  else if (fromUnit === "kelvin") celsiusValue = fromAmount - 273.15;
  else celsiusValue = fromAmount;
  if (toUnit === "celsius") return parseFloat(celsiusValue.toFixed(2));
  else if (toUnit === "fahrenheit")
    return parseFloat(((celsiusValue * 9) / 5 + 32).toFixed(2));
  else if (toUnit === "kelvin")
    return parseFloat((celsiusValue + 273.15).toFixed(2));
  return parseFloat(celsiusValue.toFixed(2));
};

export type TimeUnit =
  | "milliseconds"
  | "seconds"
  | "minutes"
  | "hours"
  | "days"
  | "weeks"
  | "months"
  | "years";

const MS_PER_SECOND = 1000;
const MS_PER_MINUTE = 60 * MS_PER_SECOND;
const MS_PER_HOUR = 60 * MS_PER_MINUTE;
const MS_PER_DAY = 24 * MS_PER_HOUR;
const MS_PER_WEEK = 7 * MS_PER_DAY;
const MS_PER_MONTH_AVG = (365.25 / 12) * MS_PER_DAY;
const MS_PER_YEAR_AVG = 365.25 * MS_PER_DAY;

const timeToMs = (amount: number, unit: TimeUnit): number => {
  switch (unit) {
    case "milliseconds":
      return amount;
    case "seconds":
      return amount * MS_PER_SECOND;
    case "minutes":
      return amount * MS_PER_MINUTE;
    case "hours":
      return amount * MS_PER_HOUR;
    case "days":
      return amount * MS_PER_DAY;
    case "weeks":
      return amount * MS_PER_WEEK;
    case "months":
      return amount * MS_PER_MONTH_AVG;
    case "years":
      return amount * MS_PER_YEAR_AVG;
  }
};

const msToUnit = (ms: number, unit: TimeUnit): number => {
  switch (unit) {
    case "milliseconds":
      return parseFloat(ms.toFixed(0));
    case "seconds":
      return parseFloat((ms / MS_PER_SECOND).toFixed(3));
    case "minutes":
      return parseFloat((ms / MS_PER_MINUTE).toFixed(5));
    case "hours":
      return parseFloat((ms / MS_PER_HOUR).toFixed(5));
    case "days":
      return parseFloat((ms / MS_PER_DAY).toFixed(5));
    case "weeks":
      return parseFloat((ms / MS_PER_WEEK).toFixed(5));
    case "months":
      return parseFloat((ms / MS_PER_MONTH_AVG).toFixed(5));
    case "years":
      return parseFloat((ms / MS_PER_YEAR_AVG).toFixed(5));
  }
};

const convertTime = (
  fromAmount: number,
  fromUnit: TimeUnit,
  toUnit: TimeUnit,
): number => msToUnit(timeToMs(fromAmount, fromUnit), toUnit);

export interface ConverterCategory {
  label: string;
  units: { key: string; label: string }[];
  defaultFrom: string;
  defaultTo: string;
  convert: (amount: number, from: string, to: string) => string;
}

export const converterCategories: Record<string, ConverterCategory> = {
  length: {
    label: "Length",
    units: [
      { key: "yard", label: "Yards" },
      { key: "foot", label: "Feet" },
      { key: "inch", label: "Inches" },
      { key: "centimeter", label: "Centimeters" },
      { key: "meter", label: "Meters" },
      { key: "kilometer", label: "Kilometers" },
    ],
    defaultFrom: "kilometer",
    defaultTo: "meter",
    convert: (a, f, t) => String(convertWithRates(lengthRates)(a, f, t)),
  },
  weight: {
    label: "Weight",
    units: [
      { key: "ton", label: "Tons" },
      { key: "pound", label: "Pounds" },
      { key: "ounce", label: "Ounces" },
      { key: "kilogram", label: "Kilograms" },
      { key: "gram", label: "Grams" },
      { key: "milligram", label: "Milligrams" },
    ],
    defaultFrom: "kilogram",
    defaultTo: "pound",
    convert: (a, f, t) => String(convertWithRates(weightRates)(a, f, t)),
  },
  temperature: {
    label: "Temperature",
    units: [
      { key: "celsius", label: "Celsius" },
      { key: "fahrenheit", label: "Fahrenheit" },
      { key: "kelvin", label: "Kelvin" },
    ],
    defaultFrom: "celsius",
    defaultTo: "fahrenheit",
    convert: (a, f, t) =>
      String(convertTemperature(a, f as TemperatureUnit, t as TemperatureUnit)),
  },
  data: {
    label: "Data",
    units: [
      { key: "bit", label: "Bit" },
      { key: "kilobyte", label: "Kilobyte" },
      { key: "megabyte", label: "Megabyte" },
      { key: "gigabyte", label: "Gigabyte" },
      { key: "terabyte", label: "Terabyte" },
    ],
    defaultFrom: "megabyte",
    defaultTo: "gigabyte",
    convert: (a, f, t) => String(convertWithRates(dataRates)(a, f, t)),
  },
  angle: {
    label: "Angle",
    units: [
      { key: "degrees", label: "Degrees" },
      { key: "radians", label: "Radians" },
    ],
    defaultFrom: "degrees",
    defaultTo: "radians",
    convert: (a, f, t) =>
      String(convertAngle(a, f as AngleUnit, t as AngleUnit)),
  },
  time: {
    label: "Time",
    units: [
      { key: "milliseconds", label: "ms" },
      { key: "seconds", label: "Seconds" },
      { key: "minutes", label: "Minutes" },
      { key: "hours", label: "Hours" },
      { key: "days", label: "Days" },
      { key: "weeks", label: "Weeks" },
      { key: "months", label: "Months" },
      { key: "years", label: "Years" },
    ],
    defaultFrom: "hours",
    defaultTo: "minutes",
    convert: (a, f, t) => String(convertTime(a, f as TimeUnit, t as TimeUnit)),
  },
  base: {
    label: "Base",
    units: [
      { key: "2", label: "Base 2" },
      { key: "8", label: "Base 8" },
      { key: "10", label: "Base 10" },
      { key: "16", label: "Base 16" },
    ],
    defaultFrom: "10",
    defaultTo: "2",
    convert: (a, f, t) => convertBase(a, f, t),
  },
  roman: {
    label: "Roman",
    units: [
      { key: "arabic", label: "Arabic" },
      { key: "roman", label: "Roman" },
    ],
    defaultFrom: "arabic",
    defaultTo: "roman",
    // Roman→Arabic needs the raw expression (letters), so the view handles
    // that direction directly; this covers Arabic→Roman and fallbacks.
    convert: (a, f, t) => {
      if (f === "arabic" && t === "roman") return arabicToRoman(Math.round(a));
      return String(a);
    },
  },
};
