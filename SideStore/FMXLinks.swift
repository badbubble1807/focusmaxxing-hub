//
//  FMXLinks.swift
//  Focusmaxxing Hub
//
//  every address the hub talks to, in one place. change a link here and nowhere else.
//  the hub is a fork of SideStore (AGPL-3); the customer-facing name is Focusmaxxing Hub.
//

import Foundation

public enum FMXLinks {
    // the github repository this fork is published from
    public static let repository = "badbubble1807/focusmaxxing-hub"

    // the built-in app list: the hub itself plus the two custom apps. the cloud build keeps the hub entry current.
    public static let appSourceURL = URL(string: "https://raw.githubusercontent.com/\(repository)/main/source/apps.json")!

    // the "recommended / blocked sources" list SideStore used to fetch from its own servers. ours is empty on purpose.
    public static let knownSourcesURL = URL(string: "https://raw.githubusercontent.com/\(repository)/main/source/default-sources.json")!

    // the hub's own icon, shown in the app list
    public static let hubIconURL = URL(string: "https://raw.githubusercontent.com/\(repository)/main/AltStore/Resources/Icons.xcassets/AppIcon.appiconset/1024.png")!

    // the website. bought and serving from 2026-09-10; before that these three
    // pointed at the github repository and at jsdelivr.
    public static let website = "https://focusmaxxing.net"

    // the licensing page is the one the Legal row in Settings opens, and the
    // licences of the projects this app is built from require it to exist.
    public static let legalURL = URL(string: "\(website)/legal")!
    public static let upgradeURL = URL(string: "\(website)/pricing")!

    // the family dns profile, for the "install it from a link" route on the adult-websites screen.
    // it must arrive as "application/x-apple-aspen-config" or safari shows the customer a page full
    // of xml instead of offering to install it; raw.githubusercontent sends it as "text/plain",
    // which is why this used to go through jsdelivr. the website sets the header itself
    // (see netlify.toml), and unlike jsdelivr it does not cache a branch for up to twelve hours.
    public static let dnsProfileURL = URL(string: "\(website)/files/focusmaxxing-family-dns.mobileconfig")!

    // the helper (LocalDevVPN on the App Store). the enable link switches it on and it calls the hub back on our url scheme.
    public static let helperAppStoreURL = URL(string: "https://apps.apple.com/app/id6755608044")!
    public static let helperEnableURL = URL(string: "localdevvpn://enable?scheme=sidestore")!
}
