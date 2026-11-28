import { useNow } from "../hooks/useNow";
import { Widget } from "./Widget";
import { pageTitleCls, split4GridCls, subCls } from "../lib/ui";

const ZONES = [
  { label: "Dallas", tz: "America/Chicago" },
  { label: "London", tz: "Europe/London" },
  { label: "Ho Chi Minh", tz: "Asia/Ho_Chi_Minh" },
  { label: "Seoul", tz: "Asia/Seoul" },
  { label: "New York", tz: "America/New_York" },
  { label: "Frankfurt", tz: "Europe/Berlin" },
  { label: "Singapore", tz: "Asia/Singapore" },
  { label: "Melbourne", tz: "Australia/Melbourne" },
] as const;

const zoneAbbr = (tz: string, now: Date): string => {
  try {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      timeZoneName: "short",
    }).formatToParts(now);
    return parts.find((p) => p.type === "timeZoneName")?.value ?? tz;
  } catch {
    return tz;
  }
};

export const TimezonesPage = () => {
  const now = useNow(1000);
  return (
    <>
      <div className={pageTitleCls}>Timezones</div>
      <div className={split4GridCls}>
        {ZONES.map((z) => (
          <Widget key={z.tz} label={z.label}>
            <div className="mt-1 truncate text-2xl leading-tight font-bold tracking-tight tabular-nums">
              {now.toLocaleTimeString("en-US", {
                timeZone: z.tz,
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
                hour12: false,
              })}
            </div>
            <div className={subCls}>
              {now.toLocaleDateString("en-US", {
                timeZone: z.tz,
                weekday: "short",
                month: "short",
                day: "numeric",
              })}{" "}
              · {zoneAbbr(z.tz, now)}
            </div>
          </Widget>
        ))}
      </div>
    </>
  );
};
