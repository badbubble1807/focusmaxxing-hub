//
//  FMXInstallStatus.swift
//  Focusmaxxing Hub
//
//  a line of text about an install that is running ("Downloading 43%", then "Installing…"),
//  kept per app by bundle id, for the tile to show under the app's name. the install's own
//  progress ring gives the download only a fifth of the ring, so a slow download looked stuck
//  at zero for minutes; this says what is really going on.
//
//  written by DownloadAppOperation, cleared by AppManager when the install ends, read by
//  AppBannerView.
//

import Foundation

final class FMXInstallStatus {
    // posted on the main thread whenever a line changes; the bundle id is in userInfo
    static let didChangeNotification = Notification.Name("FMXInstallStatusDidChange")
    static let bundleIdentifierKey = "bundleIdentifier"

    private static let lock = NSLock()
    private static var texts: [String: String] = [:]

    static func text(for bundleIdentifier: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return texts[bundleIdentifier]
    }

    static func set(_ text: String?, for bundleIdentifier: String) {
        lock.lock()
        let changed = texts[bundleIdentifier] != text
        texts[bundleIdentifier] = text
        lock.unlock()

        guard changed else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: didChangeNotification, object: nil, userInfo: [bundleIdentifierKey: bundleIdentifier])
        }
    }
}
