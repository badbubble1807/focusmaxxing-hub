// every piece of text a customer can read, in one place. sentence case. no project names.
// {name}-style holes are filled by fill().

export const fill = (text: string, values: Record<string, string>) =>
  text.replace(/\{(\w+)\}/g, (_, key) => values[key] ?? "");

export const S = {
  appName: "Focusmaxxing Setup",
  tagline: "Puts Focusmaxxing Hub on your iPhone. You only need to do this once.",
  legal: "Open source & licensing",

  steps: {
    phone: "Plug in your phone",
    account: "Sign in with your Apple ID",
    hub: "Focusmaxxing Hub goes on your phone",
  },

  phone: {
    looking: "Looking for your phone…",
    plugIn: "Plug your iPhone into this computer with a cable and unlock it.",
    itunesNeeded:
      "This computer needs Apple's iTunes to talk to your phone. Install it from Apple's website, then plug the phone in again.",
    getItunes: "Get iTunes",
    otherProblem: "This computer cannot see phones right now.",
    pairingTitle: "Connecting to {name}…",
    pairingHint:
      "Unlock your phone. If it asks \"Trust this computer?\", tap Trust and enter your passcode.",
    cancel: "Cancel",
    ready: "{name} is ready.",
    ios: "iOS {version}",
    pairFailed: "Your phone did not accept the connection.",
    tryAgain: "Try again",
    choose: "More than one phone is plugged in. Pick the one to set up.",
    use: "Use this phone",
  },

  account: {
    intro:
      "Use your own Apple ID; the Hub asks for the same one later. Your password is not saved.",
    email: "Apple ID email",
    password: "Password",
    signIn: "Sign in",
    signingIn: "Signing in…",
    signedIn: "Signed in as {email}",
    signOut: "Sign out",
    missing: "Enter both the email and the password.",
    failed: "Apple did not accept the sign-in",
    tfaTitle: "Enter the code Apple sent",
    tfaHint: "Apple sent a six-digit code to your other devices. Type it here.",
    tfaPlaceholder: "Six-digit code",
    tfaBad: "The code has six digits.",
    tfaSubmit: "Continue",
    certsTitle: "This Apple ID is already set up on other computers",
    certsHint:
      "Apple lets an Apple ID sign apps from a limited number of computers, and that limit is used up. Continue to replace them with this computer. Apps put on other phones from those computers may stop opening.",
    certsContinue: "Continue",
    certsCancel: "Cancel",
    keyringMissing:
      "This computer cannot keep the sign-in in the Windows credential store, so it is kept in memory only. Everything still works.",
  },

  hub: {
    waitingBoth: "Waiting for the phone and the Apple ID.",
    waitingPhone: "Waiting for the phone.",
    waitingAccount: "Waiting for the Apple ID.",
    running:
      "Putting Focusmaxxing Hub on your phone. Keep the phone plugged in and unlocked; this takes a minute or two.",
    steps: {
      download: "Download Focusmaxxing Hub",
      install: "Sign it for your phone and install it",
      pairing: "Connect the Hub to your phone",
      devmode: "Check Developer Mode",
    },
    failed: "That did not work.",
    tryAgain: "Try again",
    copyError: "Copy the error",
    copied: "Copied",
    moreDetails: "More details",
    suggestionsTitle: "Things to try",
    support: "If it keeps failing, copy the error and send it to us.",
    supportLink: "Send it here",
  },

  done: {
    title: "Focusmaxxing Hub is on your phone",
    intro: "You can unplug the phone. The rest happens on the phone:",
    devModeOff:
      "Turn on Developer Mode: Settings → Privacy & Security → Developer Mode. The phone restarts and asks once more.",
    devModeUnknown:
      "If the Hub will not open: Settings → Privacy & Security → Developer Mode, turn it on. The phone restarts and asks once more.",
    devModeOn: "Developer Mode is already on, nothing to do there.",
    trust:
      "If the phone says \"Untrusted Developer\" when you open the Hub: Settings → General → VPN & Device Management, tap your Apple ID, tap Trust.",
    open: "Open Focusmaxxing Hub and follow its steps: sign in with the same Apple ID, get the helper, install Instagram and YouTube.",
    checkAgain: "Check Developer Mode again",
    checking: "Checking…",
    checkNeedsPhone: "Plug the phone in to check.",
    setUpAnother: "Set up another phone",
  },

  advanced: {
    open: "Advanced",
    title: "Advanced",
    server: "Sign-in server",
    serverOption: "Sign-in server {n}",
    serverHint:
      "Apple's sign-in goes through a stand-in server. If signing in fails with a server error, pick another one and try again.",
    resetSignIn: "Forget the Apple sign-in",
    resetSignInMessage:
      "The next sign-in asks Apple for a new two-factor code. Nothing else changes.",
    resetDone: "Forgotten. The next sign-in asks for a code.",
    resetNothing: "There was nothing to forget.",
    resetFailed: "Could not forget the sign-in",
    forgetPairing: "Forget this phone",
    forgetPairingMessage:
      "The phone will ask to trust this computer again the next time it is plugged in.",
    forgetPairingDone: "Forgotten. Plug the phone in again.",
    forgetPairingFailed: "Could not forget the phone",
    noKeyring: "Don't use the Windows credential store",
    noKeyringHint:
      "Keeps the certificate and the sign-in state in a file instead. Less safe; only for when the credential store does not work on this computer.",
    viewLog: "View the log",
    logTitle: "Log",
    copyLog: "Copy the log",
    noLog: "Nothing logged yet.",
    close: "Close",
    confirm: "Continue",
    cancel: "Cancel",
  },

  error: {
    title: "Something went wrong",
    unknown: "Unknown error",
    dismiss: "Dismiss",
  },

  // things to try, per kind of failure. ((link:url:text)) becomes a link; {anisette} is the sign-in server
  suggestions: {
    underage: [
      "This Apple ID is under the age Apple requires for this. Use another Apple ID.",
    ],
    accountLocked: [
      "Apple locked the Apple ID after too many sign-in attempts. It is harmless: unlock it at ((link:https://iforgot.apple.com/:iforgot.apple.com)) and try again.",
    ],
    auth: [
      "Check the email and password and try again, even if they looked right.",
      "Two-factor with a security key is not supported. Use an Apple ID that sends codes to a trusted device.",
      "If it keeps failing, try another Apple ID.",
    ],
    download: ["Check that this computer is online, then try again."],
    houseArrest: [
      "Unlock the phone and try again. On a beta version of iOS this step can fail; a normal release works.",
    ],
    trust: [
      "Unlock the phone, go to its home screen, and tap Trust on anything it asks.",
    ],
    pairing: [
      "Unplug the phone, plug it in again, and try again.",
      "Set a passcode on the phone (Settings → Face ID & Passcode) if it has none.",
      "Use a cable, not Wi-Fi.",
    ],
    deviceComs: [
      "Check the cable is in properly. Try another USB port or another cable.",
    ],
    usbmuxd: [
      "Install ((link:https://www.apple.com/itunes/download/win64:iTunes from Apple's website)) and check that it sees the phone.",
      "If iTunes is installed but does not see the phone, uninstall it and \"Apple Mobile Device Support\", then install \"Apple Devices\" from the Microsoft Store.",
    ],
    notLoggedIn: ["Sign in with your Apple ID first."],
    noDevice: ["Plug the phone in first."],
    anisette: [
      "Check that this computer is online.",
      "Open Advanced, pick another sign-in server, and try again.",
      "Check that ((link:{anisette}:the sign-in server)) opens in a browser.",
    ],
    keyring: [
      "Open Advanced and tick \"Don't use the Windows credential store\", then try again.",
    ],
    admin: ["Try running Focusmaxxing Setup as administrator."],
    filesystem: [
      "Make sure Focusmaxxing Setup is allowed to write files. An antivirus can block this.",
    ],
    misc: [
      "Try again. Restarting Focusmaxxing Setup, the computer or the phone can help.",
    ],
    notEnoughAppIds: [
      "This Apple ID has used up its app slots for the week. Apple frees them seven days after they were used; try again then.",
    ],
    maxApps: [
      "A free Apple ID can have three of these apps on a phone at once, expired ones included. Delete one from the phone and try again.",
    ],
  },
};

export type SuggestionKey = keyof typeof S.suggestions;
