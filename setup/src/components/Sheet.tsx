// a dialog on top of the screen, drawn with the design system's .sheet classes. sheets stack
// (the advanced sheet under its log sheet under an error); Escape closes only the top one.
//
// every sheet is drawn at the top of the page, not where it is written. a sheet covers the window
// with "position: fixed", but a card wrapping it takes that over (the design system's .card has a
// backdrop blur, and any blur, filter or transform makes the element the boundary for fixed
// children instead of the window). the pairing sheet sits inside the phone card and the code sheet
// inside the apple id card, so both were squashed into a black bar inside their card until this.

import { ReactNode, useEffect, useRef } from "react";
import { createPortal } from "react-dom";

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
  return createPortal(
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
    </div>,
    document.body,
  );
};
