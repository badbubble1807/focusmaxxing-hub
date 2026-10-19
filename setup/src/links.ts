// every web address the screen opens, in one place. the addresses the rust side uses (the hub
// download, the hub's identifier) are in src-tauri/src/links.rs.

export const links = {
  // itunes from apple's own site, which carries the usb service this program needs;
  // the microsoft store version can leave that service out
  itunes: "https://www.apple.com/itunes/download/win64",
  // the licensing page; the repository until the website exists (the hub's FMXLinks.legalURL does the same)
  legal: "https://github.com/badbubble1807/focusmaxxing-hub#open-source--licensing",
  // where a copied error goes; the repository's issues until the website exists
  support: "https://github.com/badbubble1807/focusmaxxing-hub/issues",
  // apple's own page for a locked apple id
  unlockAppleId: "https://iforgot.apple.com/",
};

// the sign-in servers apple's login needs a stand-in for ("anisette"). the first is the default;
// the others are fallbacks for when it is down. the screen shows them as "Sign-in server 1, 2, …"
// because the addresses carry project names a customer is not meant to read.
// iloader 2.3.10's list, in its order (2026-10-19). the old servers (ani.sidestore.io and the
// rest) stopped working with apple's sign-in in october 2026. the last two pretend to be a
// windows pc and, by iloader's account, work about half the time and never with a code by text.
export const anisetteServers = [
  "new.ani.sidestore.io",
  "mac-ani.jkcoxson.com",
  "ani3.stikstore.app",
  "ani.jkcoxson.com",
  "ani2.stikstore.app",
];
export const defaultAnisetteServer = anisetteServers[0];
// where the chosen one is saved. renamed with the new list, so a choice saved from the old list
// (which the sign-in would still use) is left behind
export const anisetteServerKey = "newAnisetteServer";
