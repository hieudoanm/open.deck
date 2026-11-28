import { useNow } from "../hooks/useNow";
import { clockValueCls, subCls, valueCls } from "../lib/ui";
import { Widget } from "./Widget";

const TIMEZONE = Intl.DateTimeFormat().resolvedOptions().timeZone;

export const DateWidget = () => {
  const now = useNow();
  return (
    <Widget label="Date">
      <div className={valueCls}>
        {now.toLocaleDateString([], { month: "short", day: "numeric" })}
      </div>
      <div className={subCls}>
        {now.toLocaleDateString([], { weekday: "long" })} · {now.getFullYear()}
      </div>
    </Widget>
  );
};

export const TimeWidget = () => {
  const now = useNow();
  return (
    <Widget label="Time">
      <div className={clockValueCls}>
        {now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}
      </div>
      <div className={subCls}>
        {now.toLocaleTimeString([], { second: "2-digit" })} · {TIMEZONE}
      </div>
    </Widget>
  );
};
