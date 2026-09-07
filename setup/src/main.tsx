// focusmaxxing setup - the screen. a trimmed fork of iloader (nab138, MIT): one guided flow
// instead of a toolbox. every piece of text is in strings.ts, every web address in links.ts.

import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import { StoreProvider } from "./StoreContext";
import { LogProvider } from "./LogContext";
import { ErrorProvider } from "./ErrorContext";
import { DialogProvider } from "./DialogContext";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <StoreProvider>
      <ErrorProvider>
        <DialogProvider>
          <LogProvider>
            <App />
          </LogProvider>
        </DialogProvider>
      </ErrorProvider>
    </StoreProvider>
  </React.StrictMode>,
);
