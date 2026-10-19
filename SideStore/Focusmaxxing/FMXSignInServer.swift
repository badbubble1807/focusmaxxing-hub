//
//  FMXSignInServer.swift
//  Focusmaxxing Hub
//
//  the one sign-in server ("anisette") the hub signs in to apple with, and the move onto it.
//
//  what went wrong (2026-10-19, on the owner's phone): from mid-october apple's sign-in answers
//  "Failed to sign in (-80045) this action can't be completed at this time" to the hub's own
//  on-device anisette, and to the old public servers, whatever they say they are. what works,
//  confirmed by many people on SideStore's own tracker (SideStore issues 1652 and 1658, 17-18
//  october), is a remote server again, "SideStore (New)" at new.ani.sidestore.io, with no
//  rotating onto the old servers (their provisioning is another kind, so a switch halfway means
//  starting over) and with adi.pb cleared once so the old provisioning is not reused. the
//  hub's settings rows for all of that are hidden, so the hub makes the move by itself.
//
//  Focusmaxxing Setup signs in through the same server (setup/src/links.ts).
//

import Foundation

enum FMXSignInServer {
    static let address = "https://new.ani.sidestore.io"
    // the same kind of server (all three say they are the same mac), tried in turn only when one
    // fails outright: new.ani.sidestore.io answered "502 Bad Gateway" on 2026-10-19, busy with
    // everyone moving to it. the old servers are never in here; their provisioning is another kind
    static let addresses = [address, "https://mac-ani.jkcoxson.com", "https://ani3.stikstore.app"]

    // raise this when the move has to happen again on every phone (a new server, say)
    private static let version = 1
    private static let appliedKey = "fmx.signInServer.version"

    // once per phone, at launch: remote anisette instead of on-device, only this server, and the
    // old provisioning gone, so the next sign-in starts clean with this server
    static func moveIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: appliedKey) < version else { return }

        defaults.useOnDeviceAnisette = false
        defaults.menuAnisetteURL = address
        defaults.disableAnisetteRotation = true
        AnisetteDataManager.shared.anisetteAdiBlob = nil

        defaults.set(version, forKey: appliedKey)
        debugLog("[FMXSignInServer] moved the sign-in to \(address); on-device anisette off, adi.pb cleared")
    }
}
