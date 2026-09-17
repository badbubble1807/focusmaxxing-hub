//
//  FMXFullBlock.swift
//  Focusmaxxing Hub
//
//  "Full block": blocking a whole app. the extension shows a "Full block" switch on every site;
//  on the phone that cannot be an instant toggle, because an app on a free apple account has no way
//  to block another app (Family Controls needs a paid entitlement). so a full block on the phone is
//  the same shape as the NSFW block: the hub walks the customer into Apple's own Screen Time and
//  records their tick. see FMXFullBlockViewController for the screen, and FMXAdultBlock for the
//  older twin this is modelled on.
//
//  WHY THESE ARE NOT SWITCHES. a whole-app block for Discord, TikTok, Facebook, Reddit, X or Roblox
//  has nothing of ours inside the app to read a switch - we do not build those apps. if it were an
//  fmx.block.<key> in FMXSwitchStore, nothing would enforce it AND, worse, the store reads an
//  unknown key as blocked (FMXSwitchStore.isBlocked), so the fold would light up "Active" the moment
//  it appeared, claiming a block the phone is not keeping. that is exactly the false-active the NSFW
//  screen was written to avoid. so a full block is a tick of the customer's own (fmx.fullblock.done.*),
//  never a switch, and it is never written into the shared switches file the two apps read.
//
//  THE TWO EXCEPTIONS, 2026-09-09. Instagram and YouTube are builds of ours, so the reason above
//  does not hold for them: there IS something of ours inside to read a switch. their Full block is
//  a real switch ("instagram", "ytfull" in FMXSwitchStore, the extension's own site keys), and the
//  app puts our own block screen up over itself when it is on - our mark, one of the twelve
//  messages, the media, a button that closes the app (mobile/shared/FMXBlockScreen.m). no Screen
//  Time, no entitlement, nothing to tick. they are still listed in `builtIn` below, because that is
//  what orders and names the folds; they just never reach FMXFullBlockViewController.
//

import Foundation

// one of the built-in apps the customer can whole-app block.
struct FMXFullBlockApp: Equatable {
    let id: String     // the stable key its tick is stored under: "instagram", "discord"
    let name: String   // what the customer reads: "Instagram", "X / Twitter"
}

enum FMXFullBlock {
    // the eight built-in apps, in the extension's own order (COMMON_BLOCKS in the desktop sites.js):
    // the two we also tweak part by part (Instagram, YouTube) first, then the six the extension
    // shows as a single "Full block". every name is SITES[key].label, to the letter - note the
    // spaces in "X / Twitter".
    static let builtIn: [FMXFullBlockApp] = [
        FMXFullBlockApp(id: "instagram", name: "Instagram"),
        FMXFullBlockApp(id: "youtube",   name: "YouTube"),
        FMXFullBlockApp(id: "discord",   name: "Discord"),
        FMXFullBlockApp(id: "tiktok",    name: "TikTok"),
        FMXFullBlockApp(id: "facebook",  name: "Facebook"),
        FMXFullBlockApp(id: "twitter",   name: "X / Twitter"),
        FMXFullBlockApp(id: "reddit",    name: "Reddit"),
        FMXFullBlockApp(id: "roblox",    name: "Roblox"),
    ]

    // the FMXApp whose per-part switches belong under a built-in fold, or nil for a Full-block-only
    // app. only Instagram and YouTube return non-nil - they are the two apps whose fold opens onto
    // switches; the other six open onto their one Full block row.
    static func switchApp(for id: String) -> FMXApp? {
        switch id {
        case "instagram": return .instagram
        case "youtube":   return .youtube
        default:          return nil
        }
    }

    // MARK: the customer's own tick, one per app
    //
    // the hub cannot read Screen Time, so this is a note on a list, not a reading of the phone -
    // the same as FMXAdultBlock.fmxAdultDone. stored under its own prefix, deliberately NOT under
    // fmx.block., so it can never be mistaken for an enforced switch. until it is set, the fold's
    // Full block row is grey ("Not set up"), never on, because nothing is blocked yet.
    private static func doneKey(_ id: String) -> String { return "fmx.fullblock.done.\(id)" }

    static func isSetUp(_ id: String) -> Bool {
        return UserDefaults.standard.bool(forKey: FMXFullBlock.doneKey(id))
    }

    static func setSetUp(_ done: Bool, for id: String) {
        UserDefaults.standard.set(done, forKey: FMXFullBlock.doneKey(id))
    }

    // MARK: clearing away the old Custom blocks list
    //
    // until 2026-09-17 the switches screen had a Custom blocks pane: any app the customer named,
    // each a Full block of its own, kept in the hub's own defaults as a list of {id, name} under
    // "fmx.fullblock.custom" (ids "custom.<uuid>") with its tick under
    // "fmx.fullblock.done.custom.<uuid>". the pane is gone, so a phone that saved some is cleared of
    // both here. the Screen Time limits the customer set for those apps are Apple's, not ours: the
    // hub never wrote them and cannot remove them, so they stay on the phone until the customer
    // takes them off in Settings.
    //
    // called at every launch from AppDelegate, before any screen is built. removing is safe to
    // repeat, so it needs no flag of its own. nothing is read as a particular type: the list goes
    // whatever shape it is in, and the ticks are found by their names only. the built-in ticks
    // ("fmx.fullblock.done.discord" and the rest, see builtIn) never begin with "custom.", so they
    // are never touched.
    private static let oldCustomListKey = "fmx.fullblock.custom"
    private static let oldCustomTickPrefix = "fmx.fullblock.done.custom."

    static func removeOldCustomApps() {
        let defaults = UserDefaults.standard
        var removed = 0

        if defaults.object(forKey: FMXFullBlock.oldCustomListKey) != nil {
            defaults.removeObject(forKey: FMXFullBlock.oldCustomListKey)
            removed += 1
        }

        let ticks = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(FMXFullBlock.oldCustomTickPrefix) }
        for key in ticks {
            defaults.removeObject(forKey: key)
        }
        removed += ticks.count

        if removed > 0 {
            debugLog("[FMXFullBlock] removed the old custom blocks: \(removed) saved value(s)")
        }
    }

    // MARK: the Screen Time steps, one wording for every app
    //
    // kept terse on purpose. the owner's own words on the NSFW screen were "theres just SO MUCH
    // text ... a beginners gonna get overwhelmed". so: four short steps, one sentence each, the
    // caveats live under "If something looks wrong" on the screen, not here. apple's own wording
    // (Settings -> Screen Time -> App Limits). if apple moves it, this is what to update.
    static func steps(for name: String) -> [String] {
        return [
            "Tap back to the main Settings list, then tap Screen Time. Turn it on if it asks.",
            "Tap App Limits, then Add Limit.",
            "Choose \(name), tap Next, set it to 1 minute, then tap Add.",
            "Back in Screen Time, tap Lock Screen Time Settings and set four digits.",
        ]
    }
}
