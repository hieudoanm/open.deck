import type { ReactNode } from "react";
import { cx, labelCls, widgetCls } from "../lib/ui";

export const Widget = ({
  label,
  children,
  className = "",
}: {
  label?: ReactNode;
  children: ReactNode;
  className?: string;
}) => {
  return (
    <div className={cx(widgetCls, className)}>
      {label && <div className={labelCls}>{label}</div>}
      {children}
    </div>
  );
};
