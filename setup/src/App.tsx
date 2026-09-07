// the whole screen: three steps top to bottom. the phone and the apple id can be done in either
// order; the hub install starts by itself the moment both are there.

import { useCallback, useEffect, useState } from "react";
import "./App.css";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { openUrl } from "@tauri-apps/plugin-opener";
import { Phone, DeviceInfo } from "./Phone";
import { AppleID } from "./AppleID";
import { Install, InstallResult, InstallState, OperationUpdate, applyUpdate, idleInstall } from "./Install";
import { Done } from "./Done";
import { Advanced } from "./Advanced";
import { useStore } from "./StoreContext";
import { asAppError } from "./errors";
import { S } from "./strings";
import { links, defaultAnisetteServer } from "./links";

function App() {
  const [device, setDevice] = useState<DeviceInfo | null>(null);
  // a phone just finished or forgotten is left alone until it has been unplugged once
  const [skipUdid, setSkipUdid] = useState<string | null>(null);
  const [account, setAccount] = useState<string | null>(null);
  const [install, setInstall] = useState<InstallState>(idleInstall);
  const [advancedOpen, setAdvancedOpen] = useState(false);
  const [keyringMissing, setKeyringMissing] = useState(false);
  const [anisetteServer, setAnisetteServer] = useStore<string>("anisetteServer", defaultAnisetteServer);
  const [overrideKeyring, setOverrideKeyring] = useStore<boolean>("overrideKeyring", false);

  useEffect(() => {
    (async () => {
      try {
        await invoke("force_disable_keyring", { force: overrideKeyring });
        setKeyringMissing(!(await invoke<boolean>("keyring_available")));
      } catch {
        setKeyringMissing(true);
      }
    })();
  }, [overrideKeyring]);

  const runInstall = useCallback(async () => {
    setInstall({ ...idleInstall, status: "running" });
    const unlisten = await listen<OperationUpdate>("operation_install_hub", (event) => {
      setInstall((old) => applyUpdate(old, event.payload));
    });
    try {
      const result = await invoke<InstallResult>("install_hub_operation");
      setInstall((old) => ({ ...old, status: "done", result }));
    } catch (e) {
      const error = asAppError(e);
      setInstall((old) => ({
        ...old,
        status: "failed",
        failed: old.failed.length > 0 ? old.failed : [{ stepId: "download", error }],
      }));
    } finally {
      unlisten();
    }
  }, []);

  // the install starts by itself once the phone and the apple id are both there
  useEffect(() => {
    if (device && account && install.status === "idle") runInstall();
  }, [device, account, install.status, runInstall]);

  const done = install.status === "done" && install.result !== null;
  const running = install.status === "running";

  const stepClass = (isDone: boolean, isActive: boolean) => (isDone ? "done" : isActive ? "active" : "");

  return (
    <main className="setup">
      <header className="setup-head rise">
        <div className="mark" aria-hidden="true">
          <svg viewBox="0 0 24 24">
            <path d="M13 2 3 14h7l-1 8 10-12h-7l1-8z" />
          </svg>
        </div>
        <div>
          <h1>{S.appName}</h1>
          <p className="note">{S.tagline}</p>
        </div>
      </header>

      <section className={`card step rise ${stepClass(device !== null || done, !device && !done)}`}>
        <div className="step-head">
          <span className="step-num">1</span>
          <h2>{S.steps.phone}</h2>
        </div>
        {done ? (
          <div className="status">
            <span className="tick" aria-hidden="true">
              ✓
            </span>
            <span>{device ? device.name : S.steps.phone}</span>
          </div>
        ) : (
          <Phone
            selected={device}
            setSelected={running ? () => {} : setDevice}
            skipUdid={skipUdid}
            setSkipUdid={setSkipUdid}
          />
        )}
      </section>

      <section className={`card step rise ${stepClass(account !== null, device !== null && !account)}`}>
        <div className="step-head">
          <span className="step-num">2</span>
          <h2>{S.steps.account}</h2>
        </div>
        <AppleID
          account={account}
          setAccount={setAccount}
          anisetteServer={anisetteServer}
          keyringMissing={keyringMissing}
          locked={running || done}
        />
      </section>

      <section className={`card step rise ${stepClass(done, running || install.status === "failed")} ${done ? "glow" : ""}`}>
        <div className="step-head">
          <span className="step-num">3</span>
          <h2>{done ? S.done.title : S.steps.hub}</h2>
        </div>
        {done ? (
          <Done
            result={install.result as InstallResult}
            onReset={() => {
              setSkipUdid(device?.udid ?? null);
              setInstall(idleInstall);
              setDevice(null);
            }}
          />
        ) : (
          <Install
            state={install}
            hasPhone={device !== null}
            hasAccount={account !== null}
            anisetteServer={anisetteServer}
            onRetry={() => setInstall(idleInstall)}
          />
        )}
      </section>

      <footer className="setup-foot">
        <button className="linky" onClick={() => setAdvancedOpen(true)}>
          {S.advanced.open}
        </button>
        <button className="linky" onClick={() => openUrl(links.legal)}>
          {S.legal}
        </button>
      </footer>

      <Advanced
        open={advancedOpen}
        onClose={() => setAdvancedOpen(false)}
        anisetteServer={anisetteServer}
        setAnisetteServer={setAnisetteServer}
        overrideKeyring={overrideKeyring}
        setOverrideKeyring={setOverrideKeyring}
        hasPhone={device !== null && !running && !done}
        forgetPhone={() => {
          setSkipUdid(device?.udid ?? null);
          setDevice(null);
        }}
      />
    </main>
  );
}

export default App;
