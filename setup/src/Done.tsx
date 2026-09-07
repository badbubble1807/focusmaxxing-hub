// the last screen: the hub is on the phone; what to do on the phone next. the developer mode
// line depends on what the phone said during the install, and can be checked again.

import { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { InstallResult } from "./Install";
import { S } from "./strings";

export const Done = ({ result, onReset }: { result: InstallResult; onReset: () => void }) => {
  const [developerMode, setDeveloperMode] = useState<boolean | null>(result.developerMode);
  const [checking, setChecking] = useState(false);
  const [checkNote, setCheckNote] = useState("");

  const checkAgain = async () => {
    setChecking(true);
    setCheckNote("");
    try {
      const on = await invoke<boolean>("developer_mode_status");
      setDeveloperMode(on);
    } catch {
      setCheckNote(S.done.checkNeedsPhone);
    } finally {
      setChecking(false);
    }
  };

  const devModeLine =
    developerMode === true ? S.done.devModeOn : developerMode === false ? S.done.devModeOff : S.done.devModeUnknown;

  return (
    <>
      <p className="note">{S.done.intro}</p>
      <ol className="phone-steps">
        <li className={developerMode === true ? "muted" : undefined}>{devModeLine}</li>
        <li>{S.done.trust}</li>
        <li>{S.done.open}</li>
      </ol>
      {developerMode !== true && (
        <div className="row">
          <button className="btn btn-sm" onClick={checkAgain} disabled={checking}>
            {checking ? S.done.checking : S.done.checkAgain}
          </button>
          {checkNote && <span className="hint">{checkNote}</span>}
        </div>
      )}
      <div className="row">
        <button className="linky" onClick={onReset}>
          {S.done.setUpAnother}
        </button>
      </div>
    </>
  );
};
