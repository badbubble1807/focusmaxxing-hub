// the errors the rust side sends ({ type, message }, see src-tauri/src/error.rs) and the
// suggestions that go with each kind. from iloader's errors.tsx; the texts live in strings.ts.

import { S, SuggestionKey, fill } from "./strings";

export type ErrorVariant =
  | "max_apps"
  | "not_enough_app_ids"
  | "device_coms"
  | "underage"
  | "account_locked"
  | "developer"
  | "auth"
  | "download"
  | "house_arrest"
  | "remote_pairing"
  | "lockdown_pairing"
  | "canceled"
  | "operation_update"
  | "device_coms_with_message"
  | "usbmuxd"
  | "not_logged_in"
  | "no_device_selected"
  | "anisette"
  | "keyring"
  | "keyring_with_message"
  | "storage"
  | "misc"
  | "filesystem";

export type AppError = { type: ErrorVariant; message: string };

const suggestionKeys: Record<ErrorVariant, SuggestionKey[]> = {
  underage: ["underage"],
  account_locked: ["accountLocked"],
  developer: [],
  auth: ["auth"],
  download: ["download"],
  house_arrest: ["houseArrest", "trust", "deviceComs"],
  remote_pairing: ["trust", "pairing"],
  lockdown_pairing: ["trust", "pairing"],
  canceled: [],
  operation_update: [],
  device_coms: ["deviceComs", "trust"],
  device_coms_with_message: ["deviceComs", "trust"],
  usbmuxd: ["usbmuxd", "deviceComs", "trust"],
  not_logged_in: ["notLoggedIn"],
  no_device_selected: ["noDevice"],
  anisette: ["anisette"],
  keyring: ["keyring", "admin"],
  keyring_with_message: ["keyring", "admin"],
  storage: ["keyring", "admin", "filesystem"],
  misc: ["misc"],
  filesystem: ["filesystem", "admin"],
  not_enough_app_ids: ["notEnoughAppIds"],
  max_apps: ["maxApps"],
};

// whatever a rejected call carried, as an AppError
export const asAppError = (e: unknown): AppError => {
  if (e && typeof e === "object" && "message" in e && "type" in e) {
    const candidate = e as { type: unknown; message: unknown };
    if (typeof candidate.message === "string" && typeof candidate.type === "string") {
      return { type: candidate.type as ErrorVariant, message: candidate.message };
    }
  }
  if (e instanceof Error) return { type: "misc", message: e.message };
  return { type: "misc", message: typeof e === "string" ? e : String(e) };
};

// the last "●" line of a long error report is the one that says what actually failed
export const shortMessage = (error: AppError): string => {
  const lines = error.message.split("\n").filter((line) => line.includes("●"));
  if (lines.length === 0) return error.message.replace(/^\n+/, "").trim();
  return lines[lines.length - 1].replace(/●\s*/, "").trim();
};

export const fullMessage = (error: AppError): string =>
  error.message.replace(/^\n+/, "");

const normalizeServer = (server: string) =>
  server.startsWith("http://") || server.startsWith("https://") ? server : `https://${server}`;

export const suggestionsFor = (type: ErrorVariant, anisetteServer: string): string[] => {
  const keys = suggestionKeys[type] ?? ["misc"];
  const out: string[] = [];
  for (const key of keys) {
    for (const text of S.suggestions[key]) {
      const filled = fill(text, { anisette: normalizeServer(anisetteServer) });
      if (!out.includes(filled)) out.push(filled);
    }
  }
  return out;
};

// "((link:https://x.y:shown text))" or "((link:https://x.y))" inside a suggestion
export const parseLinkToken = (token: string): { url: string; text: string } | null => {
  const match = token.match(/^\(\(link:([^)]+)\)\)$/);
  if (!match) return null;
  const payload = match[1].trim();
  if (!payload) return null;
  const lastColon = payload.lastIndexOf(":");
  if (lastColon > 0) {
    const possibleUrl = payload.slice(0, lastColon).trim();
    const possibleText = payload.slice(lastColon + 1).trim();
    if (possibleText && /^[a-z][a-z0-9+.-]*:\/\//i.test(possibleUrl)) {
      return { url: possibleUrl, text: possibleText };
    }
  }
  return { url: payload, text: payload };
};

export const splitLinks = (text: string): string[] => text.split(/(\(\(link:[^)]+\)\))/g);
