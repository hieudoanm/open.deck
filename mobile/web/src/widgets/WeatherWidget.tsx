import { useEffect, useState } from "react";
import {
  PiCloud,
  PiCloudFog,
  PiCloudLightning,
  PiCloudRain,
  PiCloudSnow,
  PiCloudSun,
  PiSun,
} from "react-icons/pi";
import {
  CITIES,
  conditionText,
  fetchWeather,
  type WeatherSample,
} from "../lib/weather";
import { listCls } from "../lib/ui";
import { Widget } from "./Widget";
import { SkeletonBar } from "./Skeleton";

const WX_ICON_CLS = "text-base text-warning shrink-0";

const WX_CITIES = [16, 1, 9].map((id) => CITIES.find((c) => c.id === id)!); // Birmingham, Dallas, Ho Chi Minh

const WeatherIcon = ({ code }: { code: number }) => {
  const props = { className: WX_ICON_CLS };
  if (code === 0 || code === 1) return <PiSun {...props} />;
  if (code === 2) return <PiCloudSun {...props} />;
  if (code === 3) return <PiCloud {...props} />;
  if (code === 45 || code === 48) return <PiCloudFog {...props} />;
  if ([71, 73, 75, 77, 85, 86].includes(code))
    return <PiCloudSnow {...props} />;
  if ([95, 96, 99].includes(code)) return <PiCloudLightning {...props} />;
  return <PiCloudRain {...props} />; // rain + drizzle + showers
};

export const WeatherWidget = () => {
  const [wx, setWx] = useState<Record<number, WeatherSample>>({});
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let live = true;
    const load = () =>
      Promise.all(
        WX_CITIES.map((c) =>
          fetchWeather(c).then(
            (s) => [c.id, s] as const,
            () => null,
          ),
        ),
      ).then((rows) => {
        if (!live) return;
        const next: Record<number, WeatherSample> = {};
        for (const r of rows) if (r) next[r[0]] = r[1];
        setWx(next);
        setFailed(Object.keys(next).length === 0);
      });
    load();
    const t = setInterval(load, 10 * 60_000);
    return () => {
      live = false;
      clearInterval(t);
    };
  }, []);

  return (
    <Widget label="Weather">
      <div className={listCls}>
        {WX_CITIES.map((c) => {
          const w = wx[c.id];
          return (
            <div className="text-muted flex flex-col gap-px py-0.5" key={c.id}>
              <div className="text-base-content inline-flex items-center gap-1.5 truncate font-medium">
                {w ? (
                  <WeatherIcon code={w.code} />
                ) : (
                  <PiCloud className={WX_ICON_CLS} />
                )}
                {c.label}
              </div>
              <div className="truncate">
                {w ? (
                  `${Math.round(w.tempC)}° · ${conditionText(w.code)} · H:${Math.round(w.tmax)}° L:${Math.round(w.tmin)}°`
                ) : failed ? (
                  "unavailable"
                ) : (
                  <SkeletonBar className="h-2.5 w-3/4" />
                )}
              </div>
            </div>
          );
        })}
      </div>
    </Widget>
  );
};
