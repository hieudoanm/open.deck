import { CryptoWidget } from "./CryptoWidget";
import { CountdownWidget } from "./CountdownWidget";
import { DateWidget, TimeWidget } from "./DateTimeWidget";
import { ForexWidget } from "./ForexWidget";
import { StockWidget } from "./StockWidget";
import { WeatherWidget } from "./WeatherWidget";
import { gridCls, pageTitleCls } from "../lib/ui";

export const WidgetsPage = () => {
  return (
    <>
      <div className={pageTitleCls}>Info</div>
      <div className={gridCls}>
        <DateWidget />
        <TimeWidget />
        <WeatherWidget />
        <CountdownWidget />
        <CryptoWidget />
        <ForexWidget />
        <StockWidget />
      </div>
    </>
  );
};
