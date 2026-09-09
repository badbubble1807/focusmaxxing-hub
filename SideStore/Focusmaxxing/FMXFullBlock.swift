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

// one app the customer can whole-app block through Screen Time: a built-in one, or one they added.
struct FMXFullBlockApp: Equatable {
    let id: String     // the stable key its tick is stored under: "instagram", "discord", "custom.<uuid>"
    let name: String   // what the customer reads: "Instagram", "X / Twitter", a name they typed
    let custom: Bool
}

enum FMXFullBlock {
    // the eight built-in apps, in the extension's own order (COMMON_BLOCKS in the desktop sites.js):
    // the two we also tweak part by part (Instagram, YouTube) first, then the six the extension
    // shows as a single "Full block". every name is SITES[key].label, to the letter - note the
    // spaces in "X / Twitter".
    static let builtIn: [FMXFullBlockApp] = [
        FMXFullBlockApp(id: "instagram", name: "Instagram",   custom: false),
        FMXFullBlockApp(id: "youtube",   name: "YouTube",     custom: false),
        FMXFullBlockApp(id: "discord",   name: "Discord",     custom: false),
        FMXFullBlockApp(id: "tiktok",    name: "TikTok",      custom: false),
        FMXFullBlockApp(id: "facebook",  name: "Facebook",    custom: false),
        FMXFullBlockApp(id: "twitter",   name: "X / Twitter", custom: false),
        FMXFullBlockApp(id: "reddit",    name: "Reddit",      custom: false),
        FMXFullBlockApp(id: "roblox",    name: "Roblox",      custom: false),
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

    // MARK: the apps the customer added themselves (the Custom blocks pane)
    //
    // each is one whole-app block set up through the same Screen Time steps; there is no per-part
    // switch for a custom app, exactly as the extension's custom sites are single "Full block"
    // entries. stored as an ordered list of {id, name} in the hub's own defaults.
    private static let customKey = "fmx.fullblock.custom"

    static func customApps() -> [FMXFullBlockApp] {
        let raw = UserDefaults.standard.array(forKey: FMXFullBlock.customKey) as? [[String: String]] ?? []
        return raw.compactMap { entry in
            guard let id = entry["id"], let name = entry["name"] else { return nil }
            return FMXFullBlockApp(id: id, name: name, custom: true)
        }
    }

    // add a custom app. returns nil if the name is empty or already in the list (case-insensitive),
    // otherwise the new app. the id is a fresh uuid, so it can never collide with a built-in id or
    // another custom one, and two apps with lookalike names keep their own ticks.
    @discardableResult
    static func addCustomApp(named name: String) -> FMXFullBlockApp? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var apps = FMXFullBlock.customApps()
        guard !apps.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }

        let app = FMXFullBlockApp(id: "custom.\(UUID().uuidString)", name: trimmed, custom: true)
        apps.append(app)
        FMXFullBlock.save(apps)
        return app
    }

    static func removeCustomApp(id: String) {
        var apps = FMXFullBlock.customApps()
        apps.removeAll { $0.id == id }
        FMXFullBlock.save(apps)
        // the tick goes with it, so a re-added app of the same name starts unset
        UserDefaults.standard.removeObject(forKey: FMXFullBlock.doneKey(id))
    }

    private static func save(_ apps: [FMXFullBlockApp]) {
        let raw = apps.map { ["id": $0.id, "name": $0.name] }
        UserDefaults.standard.set(raw, forKey: FMXFullBlock.customKey)
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
