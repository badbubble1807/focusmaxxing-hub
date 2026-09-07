// a yes/no question, drawn with the design system. from iloader's DialogContext.tsx.

import React, { createContext, useContext, useState } from "react";
import { Sheet } from "./components/Sheet";
import { S } from "./strings";

export const DialogContext = createContext<{
  confirm: (title: string, message: string, onConfirm: () => void) => void;
}>({ confirm: () => {} });

export const DialogProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [title, setTitle] = useState<string | null>(null);
  const [message, setMessage] = useState<string>("");
  const [onConfirm, setOnConfirm] = useState<(() => void) | null>(null);

  const close = () => {
    setTitle(null);
    setMessage("");
    setOnConfirm(null);
  };

  return (
    <DialogContext.Provider
      value={{
        confirm: (title, message, onConfirm) => {
          setTitle(title);
          setMessage(message);
          setOnConfirm(() => onConfirm);
        },
      }}
    >
      <Sheet
        open={title !== null}
        title={title ?? ""}
        onClose={close}
        zIndex={350}
        foot={
          <>
            <button className="btn" onClick={close}>
              {S.advanced.cancel}
            </button>
            <span className="grow" />
            <button
              className="btn btn-primary"
              onClick={() => {
                onConfirm?.();
                close();
              }}
            >
              {S.advanced.confirm}
            </button>
          </>
        }
      >
        <p className="note">{message}</p>
      </Sheet>
      {children}
    </DialogContext.Provider>
  );
};

export const useDialog = () => useContext(DialogContext);
