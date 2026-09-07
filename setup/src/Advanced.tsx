// the advanced sheet: the sign-in server, forgetting the sign-in state or the phone, the
// credential-store switch, and the log. what is left of iloader's Settings.tsx.

import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { Sheet } from "./components/Sheet";
import { useDialog } from "./DialogContext";
import { useError } from "./ErrorContext";
import { LogLevel, useLogs } from "./LogContext";
import { asAppError } from "./errors";
import { S, fill } from "./strings";
import { anisetteServers } from "./links";

export const Advanced = ({
  open,
  onClose,
  anisetteServer,
  setAnisetteServer,
  overrideKeyring,
  setOverrideKeyring,
  hasPhone,
  forgetPhone,
}: {
  open: boolean;
  onClose: () => void;
  anisetteServer: string;
  setAnisetteServer: (server: string) => void;
  overrideKeyring: boolean;
  setOverrideKeyring: (value: boolean) => void;
  hasPhone: boolean;
  forgetPhone: () => void;
}) => {
  const [note, setNote] = useState("");
  const [logOpen, setLogOpen] = useState(false);
  const [copied, setCopied] = useState(false);
  const logs = useLogs();
  const { confirm } = useDialog();
  const { err } = useError();

  const logText = logs
    .map((log) => `[${log.timestamp}] [${LogLevel[log.level]}] ${log.target ? `<${log.target}>` : ""} ${log.message}`)
    .join("\n");

  return (
    <>
      <Sheet open={open} title={S.advanced.title} onClose={onClose} zIndex={200}>
        <div className="adv">
          <div>
            <label className="label-k" htmlFor="anisette">
              {S.advanced.server}
            </label>
            <select
              id="anisette"
              className="field"
              value={anisetteServers.includes(anisetteServer) ? anisetteServer : anisetteServers[0]}
              onChange={(e) => setAnisetteServer(e.target.value)}
            >
              {anisetteServers.map((server, index) => (
                <option key={server} value={server}>
                  {fill(S.advanced.serverOption, { n: String(index + 1) })}
                </option>
              ))}
            </select>
            <p className="hint mt">{S.advanced.serverHint}</p>
          </div>

          <div className="row">
            <button
              className="btn"
              onClick={() =>
                confirm(S.advanced.resetSignIn, S.advanced.resetSignInMessage, async () => {
                  try {
                    const did = await invoke<boolean>("reset_anisette_state");
                    setNote(did ? S.advanced.resetDone : S.advanced.resetNothing);
                  } catch (e) {
                    err(S.advanced.resetFailed, asAppError(e));
                  }
                })
              }
            >
              {S.advanced.resetSignIn}
            </button>
            <button
              className="btn"
              disabled={!hasPhone}
              onClick={() =>
                confirm(S.advanced.forgetPairing, S.advanced.forgetPairingMessage, async () => {
                  try {
                    await invoke("delete_stored_rppairing");
                    await invoke("set_selected_device", { device: null });
                    forgetPhone();
                    setNote(S.advanced.forgetPairingDone);
                  } catch (e) {
                    err(S.advanced.forgetPairingFailed, asAppError(e));
                  }
                })
              }
            >
              {S.advanced.forgetPairing}
            </button>
            <button
              className="btn"
              onClick={() => {
                setCopied(false);
                setLogOpen(true);
              }}
            >
              {S.advanced.viewLog}
            </button>
          </div>
          {note && <p className="note">{note}</p>}

          <label className="check">
            <input type="checkbox" checked={overrideKeyring} onChange={(e) => setOverrideKeyring(e.target.checked)} />
            <span>
              {S.advanced.noKeyring}
              <br />
              <span className="hint">{S.advanced.noKeyringHint}</span>
            </span>
          </label>
        </div>
      </Sheet>

      <Sheet
        open={logOpen}
        title={S.advanced.logTitle}
        onClose={() => setLogOpen(false)}
        zIndex={250}
        foot={
          <>
            <button
              className="btn"
              onClick={() => {
                navigator.clipboard.writeText("```\n" + logText + "\n```");
                setCopied(true);
              }}
            >
              {copied ? S.hub.copied : S.advanced.copyLog}
            </button>
            <span className="grow" />
            <button className="btn btn-primary" onClick={() => setLogOpen(false)}>
              {S.advanced.close}
            </button>
          </>
        }
      >
        <pre className="err log">{logText || S.advanced.noLog}</pre>
      </Sheet>
    </>
  );
};
