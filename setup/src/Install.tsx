// step 3: the hub going onto the phone, one line per stage, and what to do when a stage fails.
// the rust side reports each stage over the "operation_install_hub" event (operation.rs).

import { useState } from "react";
import { Suggestions } from "./components/Suggestions";
import { AppError, fullMessage, shortMessage, suggestionsFor } from "./errors";
import { S } from "./strings";

export type StepId = "download" | "install" | "pairing" | "devmode";
export const STEP_IDS: StepId[] = ["download", "install", "pairing", "devmode"];

export type InstallResult = { developerMode: boolean | null };

export type InstallState = {
  status: "idle" | "running" | "failed" | "done";
  started: StepId[];
  completed: StepId[];
  failed: { stepId: StepId; error: AppError }[];
  result: InstallResult | null;
};

export const idleInstall: InstallState = {
  status: "idle",
  started: [],
  completed: [],
  failed: [],
  result: null,
};

export type OperationUpdate =
  | { updateType: "started" | "finished"; stepId: StepId }
  | { updateType: "failed"; stepId: StepId; extraDetails: AppError };

export const applyUpdate = (old: InstallState, update: OperationUpdate): InstallState => {
  if (update.updateType === "failed") {
    return { ...old, failed: [...old.failed, { stepId: update.stepId, error: update.extraDetails }] };
  }
  if (update.updateType === "started") return { ...old, started: [...old.started, update.stepId] };
  return { ...old, completed: [...old.completed, update.stepId] };
};

export const Install = ({
  state,
  hasPhone,
  hasAccount,
  anisetteServer,
  onRetry,
}: {
  state: InstallState;
  hasPhone: boolean;
  hasAccount: boolean;
  anisetteServer: string;
  onRetry: () => void;
}) => {
  const [moreOpen, setMoreOpen] = useState(false);
  const [copied, setCopied] = useState(false);

  if (state.status === "idle") {
    const text = !hasPhone && !hasAccount ? S.hub.waitingBoth : !hasPhone ? S.hub.waitingPhone : S.hub.waitingAccount;
    return <p className="note">{text}</p>;
  }

  const failure = state.failed[0] ?? null;
  const running = state.status === "running";

  return (
    <>
      {running && <p className="note">{S.hub.running}</p>}
      <div className="oplist">
        {STEP_IDS.map((id) => {
          const failed = state.failed.find((f) => f.stepId === id);
          const done = state.completed.includes(id);
          const started = state.started.includes(id);
          const cls = failed ? "failed" : done ? "done" : started ? "active" : "pending";
          return (
            <div key={id} className={`opstep ${cls}`}>
              <span className="ico" aria-hidden="true">
                {failed ? "✕" : done ? "✓" : started ? <span className="spin" /> : <span className="dot" />}
              </span>
              <span>{S.hub.steps[id]}</span>
            </div>
          );
        })}
      </div>
      {failure && state.status === "failed" && (
        <div className="failure">
          <p className="warn">{S.hub.failed}</p>
          <pre className="err">{shortMessage(failure.error) || S.error.unknown}</pre>
          {shortMessage(failure.error) !== fullMessage(failure.error).trim() && (
            <button className="linky" onClick={() => setMoreOpen((v) => !v)}>
              {S.hub.moreDetails} {moreOpen ? "▲" : "▼"}
            </button>
          )}
          {moreOpen && <pre className="err">{fullMessage(failure.error)}</pre>}
          <Suggestions items={suggestionsFor(failure.error.type, anisetteServer)} />
          <div className="row">
            <button className="btn btn-primary" onClick={onRetry}>
              {S.hub.tryAgain}
            </button>
            <button
              className="btn"
              onClick={() => {
                navigator.clipboard.writeText("```\n" + fullMessage(failure.error) + "\n```");
                setCopied(true);
              }}
            >
              {copied ? S.hub.copied : S.hub.copyError}
            </button>
          </div>
        </div>
      )}
    </>
  );
};
