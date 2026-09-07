// step 2: the apple id. email and password, the two-factor code apple sends, and the question
// apple asks when the id is already signing apps from other computers. from iloader's
// AppleID.tsx without the saved logins.

import { useEffect, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { emit, listen } from "@tauri-apps/api/event";
import { Sheet } from "./components/Sheet";
import { useError } from "./ErrorContext";
import { asAppError } from "./errors";
import { S, fill } from "./strings";

type CertificateInfo = {
  name: string | null;
  certificateId: string | null;
  serialNumber: string | null;
  machineName: string | null;
  machineId: string | null;
};

export const AppleID = ({
  account,
  setAccount,
  anisetteServer,
  keyringMissing,
  locked,
}: {
  account: string | null;
  setAccount: (email: string | null) => void;
  anisetteServer: string;
  keyringMissing: boolean;
  // true while the hub is being installed: no signing out half way
  locked: boolean;
}) => {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [warning, setWarning] = useState("");
  const [busy, setBusy] = useState(false);
  const [tfaOpen, setTfaOpen] = useState(false);
  const [code, setCode] = useState("");
  const [codeWarning, setCodeWarning] = useState("");
  const [certs, setCerts] = useState<CertificateInfo[] | null>(null);
  const { err } = useError();

  useEffect(() => {
    invoke<string | null>("logged_in_as")
      .then((current) => {
        if (current) setAccount(current);
      })
      .catch(() => {});
  }, [setAccount]);

  useEffect(() => {
    let stopped = false;
    const unlisteners: Array<() => void> = [];
    (async () => {
      const un1 = await listen("2fa-required", () => setTfaOpen(true));
      const un2 = await listen<CertificateInfo[]>("max-certs-reached", (event) => setCerts(event.payload));
      if (stopped) {
        un1();
        un2();
      } else {
        unlisteners.push(un1, un2);
      }
    })();
    return () => {
      stopped = true;
      for (const un of unlisteners) un();
    };
  }, []);

  const signIn = async (event: React.FormEvent) => {
    event.preventDefault();
    const trimmed = email.trim();
    if (!trimmed || !password) {
      setWarning(S.account.missing);
      return;
    }
    setWarning("");
    setBusy(true);
    try {
      await invoke("login_new", { email: trimmed, password, anisetteServer });
      setAccount(trimmed.toLowerCase());
      setPassword("");
    } catch (e) {
      err(S.account.failed, asAppError(e));
    } finally {
      setBusy(false);
      setTfaOpen(false);
      setCerts(null);
    }
  };

  const signOut = async () => {
    try {
      await invoke("invalidate_account");
    } catch {
      // nothing to sign out of
    }
    setAccount(null);
  };

  return (
    <>
      {account ? (
        <div className="status">
          <span className="tick" aria-hidden="true">
            ✓
          </span>
          <span className="grow">{fill(S.account.signedIn, { email: account })}</span>
          {!locked && (
            <button className="linky" onClick={signOut}>
              {S.account.signOut}
            </button>
          )}
        </div>
      ) : (
        <form className="form" onSubmit={signIn}>
          <p className="note">{S.account.intro}</p>
          <input
            className="field"
            type="text"
            autoComplete="username"
            placeholder={S.account.email}
            aria-label={S.account.email}
            value={email}
            disabled={busy}
            onChange={(e) => setEmail(e.target.value)}
          />
          <input
            className="field"
            type="password"
            autoComplete="current-password"
            placeholder={S.account.password}
            aria-label={S.account.password}
            value={password}
            disabled={busy}
            onChange={(e) => setPassword(e.target.value)}
          />
          {warning && <p className="warn">{warning}</p>}
          {keyringMissing && <p className="hint">{S.account.keyringMissing}</p>}
          <div className="row">
            <button className="btn btn-primary" type="submit" disabled={busy}>
              {busy && <span className="spin dark" aria-hidden="true" />}
              {busy ? S.account.signingIn : S.account.signIn}
            </button>
          </div>
        </form>
      )}

      <Sheet
        open={tfaOpen}
        title={S.account.tfaTitle}
        zIndex={300}
        foot={
          <>
            <span className="grow" />
            <button
              className="btn btn-primary"
              onClick={async () => {
                const digits = code.trim();
                if (!/^\d{6}$/.test(digits)) {
                  setCodeWarning(S.account.tfaBad);
                  return;
                }
                setCodeWarning("");
                await emit("2fa-recieved", digits);
                setTfaOpen(false);
                setCode("");
              }}
            >
              {S.account.tfaSubmit}
            </button>
          </>
        }
      >
        <form
          className="form"
          onSubmit={async (event) => {
            event.preventDefault();
            const digits = code.trim();
            if (!/^\d{6}$/.test(digits)) {
              setCodeWarning(S.account.tfaBad);
              return;
            }
            setCodeWarning("");
            await emit("2fa-recieved", digits);
            setTfaOpen(false);
            setCode("");
          }}
        >
          <p className="note">{S.account.tfaHint}</p>
          <input
            className="field"
            type="text"
            inputMode="numeric"
            autoFocus
            placeholder={S.account.tfaPlaceholder}
            aria-label={S.account.tfaPlaceholder}
            value={code}
            onChange={(e) => setCode(e.target.value)}
          />
          {codeWarning && <p className="warn">{codeWarning}</p>}
        </form>
      </Sheet>

      <Sheet
        open={certs !== null}
        title={S.account.certsTitle}
        zIndex={300}
        foot={
          <>
            <button
              className="btn"
              onClick={async () => {
                await emit("max-certs-response", null);
                setCerts(null);
              }}
            >
              {S.account.certsCancel}
            </button>
            <span className="grow" />
            <button
              className="btn btn-primary"
              onClick={async () => {
                const serials = (certs ?? [])
                  .map((cert) => cert.serialNumber)
                  .filter((serial): serial is string => !!serial);
                await emit("max-certs-response", serials.length > 0 ? serials : null);
                setCerts(null);
              }}
            >
              {S.account.certsContinue}
            </button>
          </>
        }
      >
        <p className="note">{S.account.certsHint}</p>
        {certs && certs.length > 0 && (
          <ul className="phone-steps mt">
            {certs.map((cert, index) => (
              <li key={cert.serialNumber ?? index}>
                {cert.name ?? "?"}
                {cert.machineName ? ` · ${cert.machineName}` : ""}
              </li>
            ))}
          </ul>
        )}
      </Sheet>
    </>
  );
};
