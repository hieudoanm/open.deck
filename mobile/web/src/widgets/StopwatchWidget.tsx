import { useState } from "react";
import { PiArrowCounterClockwise, PiPause, PiPlay } from "react-icons/pi";
import { useNow } from "../hooks/useNow";
import { fmtClock } from "../lib/format";
import {
  cdLineCls,
  cdLineLargeCls,
  cx,
  miniBtnCls,
  miniBtnLargeCls,
  wtActionsCls,
} from "../lib/ui";
import { Widget } from "./Widget";

export const StopwatchWidget = ({ large = false }: { large?: boolean }) => {
  const [base, setBase] = useState(0);
  const [startAt, setStartAt] = useState<number | null>(null);
  const now = useNow(100);
  const running = startAt != null;
  const elapsed = base + (running ? now.getTime() - startAt : 0);

  const toggle = () => {
    if (running) {
      setBase(elapsed);
      setStartAt(null);
    } else {
      setStartAt(now.getTime());
    }
  };

  const reset = () => {
    setBase(0);
    setStartAt(null);
  };

  return (
    <Widget label="Stopwatch">
      <div className={cx("tabular-nums", large ? cdLineLargeCls : cdLineCls)}>
        {fmtClock(elapsed)}
      </div>
      <div className={wtActionsCls}>
        <button
          className={large ? miniBtnLargeCls : miniBtnCls}
          onClick={toggle}
          aria-label={running ? "stop" : "start"}
          title={running ? "stop" : "start"}
        >
          {running ? <PiPause /> : <PiPlay />}
        </button>
        <button
          className={large ? miniBtnLargeCls : miniBtnCls}
          onClick={reset}
          aria-label="reset"
          title="reset"
        >
          <PiArrowCounterClockwise />
        </button>
      </div>
    </Widget>
  );
};
