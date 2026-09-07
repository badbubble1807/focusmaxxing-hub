// step 1: find the phone over usb and pair with it. this program looks every few seconds by
// itself (iloader had a refresh button); the first phone found is paired straight away. a phone
// that has never trusted this computer shows "Trust this computer?" at that moment and has no
// pairing record yet, so the first attempts fail; those are retried quietly for two minutes
// while the sheet tells the customer to tap Trust.

import { useCallback, useEffect, useRef, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { openUrl } from "@tauri-apps/plugin-opener";
import { Sheet } from "./components/Sheet";
import { useError } from "./ErrorContext";
import { AppError, asAppError, shortMessage } from "./errors";
import { S, fill } from "./strings";
import { links } from "./links";

export type DeviceInfo = {
  name: string;
  id: number;
  udid: string;
  connectionType: "USB" | "Network" | "Unknown";
  version: string;
};

const POLL_MS = 3000;
// how long to keep asking while the phone shows "Trust this computer?"
const TRUST_WAIT_MS = 120000;
const TRUST_RETRY_MS = 3000;

export const Phone = ({
  selected,
  setSelected,
  skipUdid,
  setSkipUdid,
}: {
  selected: DeviceInfo | null;
  setSelected: (device: DeviceInfo | null) => void;
  // a phone just finished or forgotten: left alone until it has been unplugged once
  skipUdid: string | null;
  setSkipUdid: (udid: string | null) => void;
}) => {
  const [devices, setDevices] = useState<DeviceInfo[]>([]);
  const [problem, setProblem] = useState<AppError | null>(null);
  const [pairing, setPairing] = useState<DeviceInfo | null>(null);
  const [pairFailed, setPairFailed] = useState<DeviceInfo | null>(null);
  const pairingRef = useRef(false);
  const requestRef = useRef(0);
  const retryRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const emptyTicksRef = useRef(0);
  const { err } = useError();

  const clearRetry = () => {
    if (retryRef.current) {
      clearTimeout(retryRef.current);
      retryRef.current = null;
    }
  };

  const pairRef = useRef<(device: DeviceInfo, startedAt: number) => void>(() => {});

  const pair = useCallback(
    (device: DeviceInfo, startedAt: number = Date.now()) => {
      const request = ++requestRef.current;
      clearRetry();
      pairingRef.current = true;
      setPairing(device);
      setPairFailed(null);
      invoke("set_selected_device", { device })
        .then(() => {
          if (requestRef.current !== request) return;
          pairingRef.current = false;
          setPairing(null);
          setSelected(device);
        })
        .catch((e) => {
          if (requestRef.current !== request) return;
          const error = asAppError(e);
          // no pairing record yet: the phone is still asking to trust this computer. ask again shortly
          if (error.type === "lockdown_pairing" && Date.now() - startedAt < TRUST_WAIT_MS) {
            retryRef.current = setTimeout(() => {
              retryRef.current = null;
              if (requestRef.current === request) pairRef.current(device, startedAt);
            }, TRUST_RETRY_MS);
            return;
          }
          pairingRef.current = false;
          setPairing(null);
          setPairFailed(device);
          if (error.type !== "canceled") err(S.phone.pairFailed, error);
        });
    },
    [setSelected, err],
  );

  useEffect(() => {
    pairRef.current = pair;
  }, [pair]);

  const cancelPairing = useCallback(() => {
    const device = pairing;
    requestRef.current += 1;
    clearRetry();
    pairingRef.current = false;
    setPairing(null);
    setPairFailed(device);
    invoke("cancel_pairing").catch(() => {});
  }, [pairing]);

  useEffect(() => clearRetry, []);

  // look for phones every few seconds, except while one is being paired
  useEffect(() => {
    let stopped = false;
    let busy = false;
    const tick = async () => {
      if (stopped || busy || pairingRef.current) return;
      busy = true;
      try {
        const results = await invoke<Array<{ Ok: DeviceInfo } | { Err: AppError }>>("list_devices");
        if (stopped) return;
        const found: DeviceInfo[] = [];
        for (const result of results) if ("Ok" in result) found.push(result.Ok);
        emptyTicksRef.current = found.length === 0 ? emptyTicksRef.current + 1 : 0;
        setDevices(found);
        setProblem(null);
      } catch (e) {
        if (!stopped) {
          setDevices([]);
          setProblem(asAppError(e));
        }
      } finally {
        busy = false;
      }
    };
    tick();
    const timer = setInterval(tick, POLL_MS);
    return () => {
      stopped = true;
      clearInterval(timer);
    };
  }, []);

  // pick the phone by itself when there is exactly one; notice when it is unplugged (two empty
  // looks in a row, so one missed answer does not count)
  useEffect(() => {
    if (pairing) return;
    if (selected) {
      const gone =
        devices.length > 0 ? !devices.some((d) => d.udid === selected.udid) : emptyTicksRef.current >= 2;
      if (gone) setSelected(null);
      return;
    }
    if (devices.length === 0) {
      if (pairFailed) setPairFailed(null);
      if (skipUdid) setSkipUdid(null);
      return;
    }
    const usb = devices.filter((d) => d.connectionType === "USB");
    const candidates = usb.length > 0 ? usb : devices;
    if (candidates.length === 1 && candidates[0].udid !== pairFailed?.udid && candidates[0].udid !== skipUdid) {
      pair(candidates[0]);
    }
  }, [devices, selected, pairing, pairFailed, skipUdid, setSkipUdid, pair, setSelected]);

  let body: React.ReactNode;
  if (selected) {
    body = (
      <div className="status">
        <span className="tick" aria-hidden="true">
          ✓
        </span>
        <span>
          {fill(S.phone.ready, { name: selected.name })}{" "}
          <span className="muted">{fill(S.phone.ios, { version: selected.version })}</span>
        </span>
      </div>
    );
  } else if (problem && problem.type === "usbmuxd") {
    body = (
      <>
        <p className="note">{S.phone.itunesNeeded}</p>
        <div className="row">
          <button className="btn btn-primary" onClick={() => openUrl(links.itunes)}>
            {S.phone.getItunes}
          </button>
        </div>
      </>
    );
  } else if (problem) {
    body = (
      <>
        <p className="note">{S.phone.otherProblem}</p>
        <pre className="err">{shortMessage(problem)}</pre>
      </>
    );
  } else if (pairing) {
    body = (
      <div className="status">
        <span className="spin" aria-hidden="true" />
        <span>{fill(S.phone.pairingTitle, { name: pairing.name })}</span>
      </div>
    );
  } else if (pairFailed) {
    body = (
      <>
        <p className="note">{S.phone.pairFailed}</p>
        <div className="row">
          <button className="btn btn-primary" onClick={() => pair(pairFailed)}>
            {S.phone.tryAgain}
          </button>
        </div>
      </>
    );
  } else if (devices.length > 1) {
    body = (
      <>
        <p className="note">{S.phone.choose}</p>
        <div className="list">
          {devices.map((device) => (
            <div key={device.udid} className="list-row">
              <div className="grow">
                <div className="name">{device.name}</div>
                <div className="desc">
                  {fill(S.phone.ios, { version: device.version })} · {device.connectionType}
                </div>
              </div>
              <button className="btn btn-sm btn-primary" onClick={() => pair(device)}>
                {S.phone.use}
              </button>
            </div>
          ))}
        </div>
      </>
    );
  } else {
    body = (
      <>
        <div className="status">
          <span className="spin" aria-hidden="true" />
          <span>{S.phone.looking}</span>
        </div>
        <p className="note">{S.phone.plugIn}</p>
      </>
    );
  }

  return (
    <>
      {body}
      <Sheet
        open={pairing !== null}
        title={fill(S.phone.pairingTitle, { name: pairing?.name ?? "" })}
        zIndex={220}
        foot={
          <>
            <span className="grow" />
            <button className="btn" onClick={cancelPairing}>
              {S.phone.cancel}
            </button>
          </>
        }
      >
        <div className="status">
          <span className="spin" aria-hidden="true" />
          <span>{S.phone.pairingHint}</span>
        </div>
      </Sheet>
    </>
  );
};
