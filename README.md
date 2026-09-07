# Focusmaxxing Hub

The phone half of focusmaxxing. Focusmaxxing Hub installs **Custom blocked Instagram** and **Custom blocked YouTube** on an iPhone with the owner's own Apple ID, keeps them working by renewing them in the background, and holds the switches that block the distracting parts of each app.

Focusmaxxing Hub is a fork of [SideStore](https://github.com/SideStore/SideStore), which is itself a fork of [AltStore](https://github.com/altstoreio/AltStore). It is published here because SideStore is licensed under the GNU AGPL v3, which asks that anyone who receives the app can also get its source. See [Open Source & Licensing](#open-source--licensing).

## What is in it

- **Switches**: one row per switch for Instagram and YouTube. Green is blocked, red is allowed. Blocking is instant; unblocking makes you wait (10 to 30 seconds, set at the bottom), and the wait can only be changed once every 24 hours. Everything starts blocked. A change applies the next time the app is opened. The switches are written to a small file in the hub's shared folder, which the custom apps read.
- **Adult websites**: the first row of the switches screen, and a screen of its own behind it. The hub cannot filter websites itself, so the switch carries the same wait as every other one, and the screen walks you through the two things on the phone that do the blocking: Apple's Screen Time restriction, locked with a Screen Time passcode, and a DNS profile pointing the phone at Cloudflare's family resolver. Both keep working if the hub is deleted; the DNS one can be switched off in Settings, and the screen says so. The profile is [`source/focusmaxxing-family-dns.mobileconfig`](source/focusmaxxing-family-dns.mobileconfig), generated from the app's own copy by [`scripts/fmx/dns-profile.js`](scripts/fmx/dns-profile.js).
- **Apps**: two tiles, Custom blocked Instagram and Custom blocked YouTube, each with one Install / Open / Update button. There is no browsing and no way to add anything else.
- **My Apps**: what is installed and how many days each app has left; SideStore's screen.
- **Settings**: the Apple ID, an Upgrade to Pro row, the reminder (a notification a day before an app stops opening if the hub could not renew it by itself; the number of days is adjustable), background renewal, a health check and the error log, and a Legal row that opens the licensing page.
- **First run**: the five setup steps, one screen each, one button each. The hub fetches the helper from the App Store and switches it on itself; the only helper-related tap is Apple's one-time "Allow VPN configuration".

Our own code is in [`SideStore/Focusmaxxing/`](SideStore/Focusmaxxing/) and [`AltStore/TabBarController.swift`](AltStore/TabBarController.swift).

## What is changed from SideStore

- The name, icon and every piece of text a customer can read say Focusmaxxing Hub.
- Four tabs instead of five: Switches, Apps, My Apps, Settings. News and Sources are gone.
- The built-in app list is [`source/apps.json`](source/apps.json): the hub itself and the two custom apps, nothing else. The old "recommended sources" list is replaced by an empty one, [`source/default-sources.json`](source/default-sources.json).
- Settings: the Patreon, alternate-icon, tutorial and beta-channel sections are hidden; a **Legal** section with one row, *Open source & licensing*, opens the licensing page; feedback goes to this repository's issues.
- SideStore's own workflows, issue templates and alternate icons are removed; one workflow, **build hub**, replaces them.
- Every address the app talks to is in [`SideStore/FMXLinks.swift`](SideStore/FMXLinks.swift).
- Before the hub reuses the Apple sign-in it keeps in memory, it checks that Apple still accepts it, and if not it signs in again silently with what is in the keychain. SideStore reused the session without looking, so once it had gone stale every install failed with "Your session has expired" until the app was closed fully.
- App downloads use a background session, so they keep going when the hub is left, and the line under the app's name on its tile says "Downloading 43%" and then "Installing…" while an install runs.
- A tile says **Update** when the app list carries a newer build number (`buildVersion`). The custom apps keep Instagram's and YouTube's own version numbers, which never change with a rebuild, so SideStore's version comparison alone never noticed a new build. [`scripts/fmx/publish-apps.js`](scripts/fmx/publish-apps.js) writes the build number into the list. For this list only, the hub does not compare that number with the downloaded app's own build number (which stays Instagram's or YouTube's); the file is checked against its checksum instead.
- A reminder: one notification, by default a day before the first app stops opening, booked again after every renewal so it only fires when the hub could not renew the app by itself. The number of days is set in Settings.
- Settings is trimmed to what a customer needs: Account, Focusmaxxing Pro, Reminder, Background refresh, Health check and Error log, Legal, and an Advanced section with Send feedback, Refresh attempts and Reset pairing file. SideStore's other rows stay in the storyboard, unseen.
- At every launch the hub removes any source other than its own list. A hub installed over SideStore inherited SideStore's source, which failed to load at each launch ("Some sources were unable to load") and held a second entry for the hub itself.

Everything else, the signing, the pairing with the helper, the background refresh, is SideStore's, unchanged, pinned at commit `a6ca4d1620e619158fa27d4e652e1f865b461f8b` (the 2026-09-05 nightly).

The app's identifier is still `com.SideStore.SideStore` on purpose: it lets the hub be installed over an existing SideStore, and the signing library inside Focusmaxxing Setup recognises that exact identifier as a store app, which is what makes it bake the signing certificate into the hub so the hub can renew itself. Changing it means teaching that library the new identifier first (see [`setup/src-tauri/src/links.rs`](setup/src-tauri/src/links.rs)).

## Building

There is no need for a Mac. Open the **Actions** tab, pick **build hub**, press **Run workflow**. About twenty minutes later the finished app is on the [hub release](../../releases/tag/hub) as `focusmaxxing-hub.ipa`, and the hub's entry in `source/apps.json` is bumped to the new version so an installed hub offers the update by itself.

To build on a Mac instead: `make build fakesign ipa` in this folder, the same as SideStore.

## Installing it on a phone that already has SideStore

Download `focusmaxxing-hub.ipa` from the hub release on the phone, open it, choose SideStore. Because the identifier is the same, SideStore installs it over itself: same Apple ID session, same pairing, new name and icon.

## Focusmaxxing Setup (the computer step)

[`setup/`](setup/) is Focusmaxxing Setup, the Windows program that puts the hub on a phone the first time: plug the phone in, sign in with the Apple ID, and the hub is downloaded from the [hub release](../../releases/tag/hub), signed for that phone, installed, and given its pairing file and the signing certificate it was signed with. It then reads whether Developer Mode is on and tells the customer what to do on the phone.

The certificate step matters more than it looks. A free Apple ID is allowed one development certificate, so if the hub cannot reuse the one it was signed with it asks Apple for another, and Apple takes the first one away — the hub is then wearing a revoked certificate and the apps it installed can no longer be renewed. So Setup writes the certificate and its private key into the hub's own Documents folder as `FocusmaxxingCertificate.plist` ([`hand_certificate_to_hub`](setup/src-tauri/src/sideload.rs)), and the hub takes it in at start-up and deletes the file ([`FMXCertificateHandoff.swift`](SideStore/Focusmaxxing/FMXCertificateHandoff.swift)). The signing library also bakes the same certificate into the app bundle as `ALTCertificate.p12`, locked with the machine id Apple gave it; that path is still there for a hub that arrives some other way, but it is the one that failed on real hardware.

It is a trimmed fork of [iloader](https://github.com/nab138/iloader) by nab138 (MIT): the phone, Apple and signing code is iloader's; the toolbox around it (importing other apps, the certificate and app id managers, the pairing manager, saved passwords, the auto-updater) is gone, the screen is one guided flow wearing the focusmaxxing design system, and one thing is added, the Developer Mode check. Every address it uses is in [`setup/src-tauri/src/links.rs`](setup/src-tauri/src/links.rs) and [`setup/src/links.ts`](setup/src/links.ts); every piece of text in [`setup/src/strings.ts`](setup/src/strings.ts).

Building: Actions → **build setup** → Run workflow (or `node scripts/fmx/dispatch.js setup` from a PC with push access). About ten minutes later the [setup release](../../releases/tag/setup) carries `focusmaxxing-setup.exe` (run it, nothing to install) and `focusmaxxing-setup-installer.exe`. Both are unsigned, so Windows shows "Windows protected your PC" once: More info, Run anyway. The computer needs iTunes from Apple's website; the Microsoft Store one can lack the phone service. A Mac build is a later step.

To work on it: `npm install` in `setup/`, then `npm run tauri dev` (needs Rust and the Tauri prerequisites); `npm run build` alone checks the screen without Rust.

## Open Source & Licensing

Focusmaxxing Hub is free software under the [GNU Affero General Public License v3](LICENSE). It is built from:

- **SideStore** by the SideStore team (AGPL-3): https://github.com/SideStore/SideStore
- **AltStore** by Riley Testut (AGPL-3): https://github.com/altstoreio/AltStore
- **minimuxer** and **em_proxy** by jkcoxson (MIT): https://github.com/SideStore/minimuxer
- **Roxas** by Riley Testut (MIT)

The VPN helper the hub needs is **LocalDevVPN** by jkcoxson, a separate free app on the App Store. It is not part of this repository and keeps its own name.

Focusmaxxing Setup, in [`setup/`](setup/), is free software under the [MIT License](setup/LICENSE). It is built from:

- **iloader** by nab138 (MIT): https://github.com/nab138/iloader (the iloader name and logo are not used)
- **isideload** by nab138 (MIT): https://github.com/nab138/isideload
- **idevice** by jkcoxson (MIT): https://github.com/jkcoxson/idevice
- **Tauri** (MIT / Apache-2.0): https://tauri.app

The two custom apps are built from their own open-source projects; their source lives in the focusmaxxing-mobile repository and is offered under the same terms (SCInsta, GPL-3; LiveContainer, AGPL-3).

## Pro

The Pro tier signs plain Instagram and YouTube for your phone on our own developer account, with no helper, no computer step and no seven-day renewals. It is not available yet.
