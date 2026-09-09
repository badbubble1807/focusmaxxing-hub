//
//  FMXMediaStore.swift
//  Focusmaxxing Hub
//
//  the block media: the pictures, GIFs, clips and sounds the block screen inside Custom blocked
//  Instagram and Custom blocked YouTube plays one of at random, under the message.
//
//  the same idea as the desktop's block media, but the phone keeps its own set. nothing carries
//  files from the computer to the phone yet (CHECKLIST.md, section C - that needs the shared
//  account server, step 3), so these are added here, on the phone, and live here. when step 3
//  exists this is the folder it fills.
//
//  where they go: a folder named `focusmaxxing-media` beside focusmaxxing-switches.plist, inside
//  the app-group folder shared with the two custom apps. the folder IS the list - there is no index
//  file, so the hub and the apps can never disagree about what is in it, and deleting a file is all
//  deleting takes. mobile/shared/FMXMedia.m is the reading half; the folder name is the contract.
//
//  what counts as one: only what an iPhone plays unhelped. that is a shorter list than the
//  desktop's MEDIA_TYPES in sites.js, which also allows webm, ogg and flac because Chromium plays
//  them and iOS does not.
//

import Foundation
import UIKit

enum FMXMediaStore {
    // the folder name is a contract with mobile/shared/FMXMedia.m. change it in both.
    static let folderName = "focusmaxxing-media"

    // the desktop's own cap (MAX_MEDIA in sites.js). twenty is plenty for a screen that shows one.
    static let maxCount = 20

    // per file. the desktop allows 250 MB because a computer has the room; a phone holds this set
    // in its app-group folder alongside everything else, so it is set where a downloaded clip
    // comfortably fits and twenty of them cannot fill the phone.
    static let maxBytes = 100 * 1024 * 1024

    static let imageExtensions = ["png", "jpg", "jpeg", "heic", "heif", "gif"]
    static let videoExtensions = ["mp4", "m4v", "mov"]
    static let soundExtensions = ["mp3", "m4a", "wav", "aac", "caf"]

    static var allowedExtensions: [String] {
        return self.imageExtensions + self.videoExtensions + self.soundExtensions
    }

    static var folderURL: URL? {
        return FileManager.default.altstoreSharedDirectory?.appendingPathComponent(self.folderName)
    }

    /// everything playable in the folder, oldest name first. empty until something is added.
    static func list() -> [URL] {
        guard let folder = self.folderURL else { return [] }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names
            .filter { !$0.hasPrefix(".") && self.allowedExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .sorted()
            .map { folder.appendingPathComponent($0) }
    }

    static func count() -> Int {
        return self.list().count
    }

    /// what went wrong, in words a person reads, or nil when it worked.
    @discardableResult
    static func add(data: Data, extension ext: String) -> String? {
        let ext = ext.lowercased()
        guard self.allowedExtensions.contains(ext) else {
            return "That kind of file won't play on an iPhone."
        }
        guard data.count <= self.maxBytes else {
            return "That file is too big. The limit is \(self.maxBytes / (1024 * 1024)) MB."
        }
        guard self.count() < self.maxCount else {
            return "You already have \(self.maxCount). Remove one first."
        }
        guard let folder = self.folderURL else {
            return "The Hub can't reach its shared folder yet."
        }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent("\(UUID().uuidString).\(ext)")
            try data.write(to: url, options: .atomic)
            debugLog("[focusmaxxing] block media added: \(url.lastPathComponent) (\(data.count) bytes)")
            return nil
        } catch {
            debugLog("[focusmaxxing] could not save block media: \(error)")
            return "The Hub couldn't save that file."
        }
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    static func removeAll() {
        for url in self.list() { self.remove(url) }
    }

    /// a still to show in the list. a picture is itself; a clip and a sound get a symbol.
    static func thumbnail(for url: URL) -> UIImage? {
        let ext = url.pathExtension.lowercased()
        if self.imageExtensions.contains(ext) {
            return UIImage(contentsOfFile: url.path)
        }
        if self.videoExtensions.contains(ext) {
            return UIImage(systemName: "film.fill")
        }
        return UIImage(systemName: "speaker.wave.2.fill")
    }

    /// "Picture", "Clip", "Sound" - what a row says it is.
    static func kindName(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext == "gif" { return "GIF" }
        if self.imageExtensions.contains(ext) { return "Picture" }
        if self.videoExtensions.contains(ext) { return "Clip" }
        return "Sound"
    }
}
