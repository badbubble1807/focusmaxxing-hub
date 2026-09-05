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

    // website pages. the domain is not decided yet; these open the github repository until it is.
    public static let legalURL = URL(string: "https://github.com/\(repository)#open-source--licensing")!
    public static let upgradeURL = URL(string: "https://github.com/\(repository)#pro")!

    // the helper (LocalDevVPN on the App Store). the enable link switches it on and it calls the hub back on our url scheme.
    public static let helperAppStoreURL = URL(string: "https://apps.apple.com/app/id6755608044")!
    public static let helperEnableURL = URL(string: "localdevvpn://enable?scheme=sidestore")!
}
