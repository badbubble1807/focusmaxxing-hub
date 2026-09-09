//
//  FMXSwitchStore.swift
//  Focusmaxxing Hub
//
//  the switches, the wait, and the 24-hour lock on the wait, for both custom apps.
//  a port of mobile/shared/FMXStore.m into the hub. the keys are the same ones the
//  apps already use ("fmx.block.igfeed" and so on), so the apps can read the result.
//
//  a switch is blocked (the volt gradient) or allowed (a plain grey track). blocking is
//  instant. unblocking is the switches screen's job: it makes you sit through the wait
//  first. this store only records the result, in the hub's own settings and in one small
//  file inside the shared app-group folder that the custom apps read when they are opened.
//

import Foundation

enum FMXApp: String, CaseIterable {
    case instagram
    case youtube

    // the name a person sees
    var title: String {
        switch self {
        case .instagram: return "Instagram"
        case .youtube: return "YouTube"
        }
    }
}

struct FMXSwitch {
    let key: String      // the key the app reads, never shown
    let label: String    // what a person reads: "Disable feed"
    let app: FMXApp
}

final class FMXSwitchStore {
    static let shared = FMXSwitchStore()

    // posted on the main thread after a switch changes, with the key as the object
    static let changedNotification = Notification.Name("FMXSwitchChanged")

    static let minWait = 10
    static let maxWait = 30
    static let defaultWait = 15
    static let waitLock: TimeInterval = 24 * 60 * 60

    // the file the custom apps read; it sits in the hub's shared app-group folder
    static let sharedFileName = "focusmaxxing-switches.plist"

    // one row per switch, same keys and order as the apps' own lists
    // (mobile/instagram/src/Focusmaxxing/FMXInstagram.x and mobile/youtube/Sources/FMXYouTube.x).
    //
    // the words are the extension's, to the letter: each one is `SITES[key].sub` in the desktop
    // repository's sites.js, which is what the popup and the windows app print on the same switch.
    // one product, one set of names. the only one with no twin over there is Instagram's comments,
    // which the extension does not have a switch for; it is written in the same shape as the rest.
    //
    // the first switch of each app is the whole app rather than a part of it. its key is the
    // extension's own site key ("instagram", "ytfull" in sites.js), not an ig/yt one, because
    // that is what the desktop calls it. when it is on the custom app puts our own block screen
    // up over everything the moment it is opened (mobile/shared/FMXBlockScreen.m).
    let switches: [FMXSwitch] = [
        FMXSwitch(key: "instagram",   label: "Full block",                app: .instagram),
        FMXSwitch(key: "igfeed",      label: "Disable feed",              app: .instagram),
        FMXSwitch(key: "igreels",     label: "Disable reels",             app: .instagram),
        FMXSwitch(key: "igstories",   label: "Disable stories",           app: .instagram),
        FMXSwitch(key: "ignotifs",    label: "Disable notifs",            app: .instagram),
        FMXSwitch(key: "igsuggested", label: "Disable suggested for you", app: .instagram),
        FMXSwitch(key: "igmessages",  label: "Disable messages",          app: .instagram),
        FMXSwitch(key: "igcomments",  label: "Disable comments",          app: .instagram),

        FMXSwitch(key: "ytfull",      label: "Full block",                app: .youtube),
        FMXSwitch(key: "ytrecs",      label: "Disable recommendations",   app: .youtube),
        FMXSwitch(key: "ytcomments",  label: "Disable comments",          app: .youtube),
        FMXSwitch(key: "ytnotifs",    label: "Disable notifs",            app: .youtube),
        FMXSwitch(key: "ytscroll",    label: "Disable Shorts scroll",     app: .youtube),
        FMXSwitch(key: "ads",         label: "Block ads in YouTube",      app: .youtube),
    ]

    private let defaults = UserDefaults.standard
    private let blockPrefix = "fmx.block."
    private let waitKey = "fmx.wait"
    private let waitChangedKey = "fmx.waitChangedAt"

    private init() {}

    func switches(for app: FMXApp) -> [FMXSwitch] {
        return self.switches.filter { $0.app == app }
    }

    func isBlocked(_ key: String) -> Bool {
        // everything starts blocked, the same as the desktop
        guard let stored = self.defaults.object(forKey: self.blockPrefix + key) as? Bool else { return true }
        return stored
    }

    func setBlocked(_ blocked: Bool, key: String) {
        self.defaults.set(blocked, forKey: self.blockPrefix + key)
        self.export()
        debugLog("[focusmaxxing] \(key) -> \(blocked ? "blocked" : "allowed")")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: FMXSwitchStore.changedNotification, object: key)
        }
    }

    // MARK: the wait

    private func clamp(_ seconds: Int) -> Int {
        return min(max(seconds, FMXSwitchStore.minWait), FMXSwitchStore.maxWait)
    }

    var waitSeconds: Int {
        guard let stored = self.defaults.object(forKey: self.waitKey) as? Int else { return FMXSwitchStore.defaultWait }
        return self.clamp(stored)
    }

    // 0 when the slider is free
    var waitLockRemaining: TimeInterval {
        let changedAt = self.defaults.double(forKey: self.waitChangedKey)
        guard changedAt > 0 else { return 0 }
        let left = FMXSwitchStore.waitLock - (Date().timeIntervalSince1970 - changedAt)
        return max(left, 0)
    }

    // false while locked
    @discardableResult
    func setWaitSeconds(_ seconds: Int) -> Bool {
        let seconds = self.clamp(seconds)
        if seconds == self.waitSeconds { return true }
        if self.waitLockRemaining > 0 { return false }
        self.defaults.set(seconds, forKey: self.waitKey)
        self.defaults.set(Date().timeIntervalSince1970, forKey: self.waitChangedKey)
        self.export()
        return true
    }

    // "23h 12m"
    func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "\(total)s"
    }

    // MARK: the shared file

    var sharedFileURL: URL? {
        return FileManager.default.altstoreSharedDirectory?.appendingPathComponent(FMXSwitchStore.sharedFileName)
    }

    // write every switch and the wait into the shared folder. called on every change and once at launch,
    // so the file is there even before anything has been touched.
    func export() {
        guard let url = self.sharedFileURL else {
            debugLog("[focusmaxxing] no shared app-group folder; the apps cannot read the switches yet")
            return
        }
        var dictionary = [String: Any]()
        for s in self.switches {
            dictionary[self.blockPrefix + s.key] = self.isBlocked(s.key)
        }
        // the adult-websites switch (FMXAdultBlock) is not one of the app switches - nothing inside
        // instagram or youtube reads it - but it goes in the same file so the phone's whole state
        // sits in one place.
        dictionary[self.blockPrefix + FMXAdultBlock.switchKey] = self.isBlocked(FMXAdultBlock.switchKey)
        dictionary[self.waitKey] = self.waitSeconds
        dictionary[self.waitChangedKey] = self.defaults.double(forKey: self.waitChangedKey)
        dictionary["fmx.updatedAt"] = Date().timeIntervalSince1970
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            try data.write(to: url, options: .atomic)
        } catch {
            debugLog("[focusmaxxing] could not write \(url.lastPathComponent): \(error)")
        }
    }
}
