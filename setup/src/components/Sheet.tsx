// a dialog on top of the screen, drawn with the design system's .sheet classes. sheets stack
// (the advanced sheet under its log sheet under an error); Escape closes only the top one.

import { ReactNode, useEffect, useRef } from "react";

const openStack: symbol[] = [];

export const Sheet = ({
  open,
  title,
  onClose,
  children,
  foot,
  zIndex,
}: {
  open: boolean;
  title: string;
  onClose?: () => void;
  children: ReactNode;
  foot?: ReactNode;
  zIndex?: number;
}) => {
  const idRef = useRef<symbol | null>(null);
  if (idRef.current === null) idRef.current = Symbol("sheet");

  useEffect(() => {
    if (!open) return;
    const id = idRef.current as symbol;
    openStack.push(id);
    return () => {
      const at = openStack.lastIndexOf(id);
      if (at >= 0) openStack.splice(at, 1);
    };
  }, [open]);

  useEffect(() => {
    if (!open || !onClose) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape" && openStack[openStack.length - 1] === idRef.current) {
        event.preventDefault();
        onClose();
      }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div
      className="sheet-backdrop"
      style={zIndex ? { zIndex } : undefined}
      onMouseDown={(event) => {
        if (event.target === event.currentTarget && onClose) onClose();
      }}
    >
      <div className="sheet" role="dialog" aria-modal="true" aria-label={title}>
        <div className="sheet-head">
          <h2>{title}</h2>
          {onClose && (
            <button className="btn btn-icon sm btn-ghost" onClick={onClose} aria-label="Close">
              ✕
            </button>
          )}
        </div>
        <div className="sheet-body">{children}</div>
        {foot && <div className="sheet-foot">{foot}</div>}
      </div>
    </div>
  );
};
