// one place that shows an error: the short reason, things to try, the full text on request,
// and a copy button. from iloader's ErrorContext.tsx, drawn with the design system.

import React, { createContext, useContext, useState } from "react";
import { Sheet } from "./components/Sheet";
import { Suggestions } from "./components/Suggestions";
import { useStore } from "./StoreContext";
import { AppError, fullMessage, shortMessage, suggestionsFor } from "./errors";
import { S } from "./strings";
import { defaultAnisetteServer } from "./links";

export const ErrorContext = createContext<{
  err: (title: string, error: AppError) => void;
}>({ err: () => {} });

export const ErrorProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [title, setTitle] = useState<string | null>(null);
  const [error, setError] = useState<AppError | null>(null);
  const [moreOpen, setMoreOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const [anisetteServer] = useStore<string>("anisetteServer", defaultAnisetteServer);

  const close = () => {
    setTitle(null);
    setError(null);
    setMoreOpen(false);
    setCopied(false);
  };

  const short = error ? shortMessage(error) : "";
  const full = error ? fullMessage(error) : "";

  return (
    <ErrorContext.Provider
      value={{
        err: (title, error) => {
          console.log(error);
          setTitle(title);
          setError(error);
          setMoreOpen(false);
          setCopied(false);
        },
      }}
    >
      <Sheet
        open={error !== null}
        title={title ?? S.error.title}
        onClose={close}
        zIndex={400}
        foot={
          <>
            <button
              className="btn"
              onClick={() => {
                navigator.clipboard.writeText("```\n" + (full || S.error.unknown) + "\n```");
                setCopied(true);
              }}
            >
              {copied ? S.hub.copied : S.hub.copyError}
            </button>
            <span className="grow" />
            <button className="btn btn-primary" onClick={close}>
              {S.error.dismiss}
            </button>
          </>
        }
      >
        {error && (
          <>
            <pre className="err">{short || S.error.unknown}</pre>
            {short && short !== full.trim() && (
              <button className="linky mt" onClick={() => setMoreOpen((v) => !v)}>
                {S.hub.moreDetails} {moreOpen ? "▲" : "▼"}
              </button>
            )}
            {moreOpen && <pre className="err">{full}</pre>}
            <div className="mt">
              <Suggestions items={suggestionsFor(error.type, anisetteServer)} />
            </div>
          </>
        )}
      </Sheet>
      {children}
    </ErrorContext.Provider>
  );
};

export const useError = () => useContext(ErrorContext);
