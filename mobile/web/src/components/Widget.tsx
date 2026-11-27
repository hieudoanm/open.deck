import type { ReactNode } from "react";

export function Widget({
  label,
  children,
  className = "",
}: {
  label?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className={`widget ${className}`}>
      {label && <div className="label">{label}</div>}
      {children}
    </div>
  );
}
