//
//  FMXBackgroundDownload.swift
//  Focusmaxxing Hub
//
//  downloads an app file with a background url session, so the download keeps going when the
//  hub is left. SideStore downloaded with a plain session, and ios paused that within about
//  half a minute of the hub going to the background; a 250 MB app on slow wi-fi then needed
//  the hub kept open the whole time.
//
//  what ios promises: the download itself continues while the hub is in the background, and
//  when it finishes the hub is woken briefly to take the file. the rest of the install
//  (checking, signing, sending the app to the phone) is the hub's own work and only runs while
//  ios lets the hub run; if it cannot finish in the background it carries on the next time
//  the hub is opened.
//
//  one session per download, with an identifier of its own. if the hub was closed fully and
//  ios relaunches it to hand over a finished download, the install that download belonged to
//  is gone, so the file is of no use and the event is simply acknowledged.
//

import UIKit

final class FMXBackgroundDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private static let identifierPrefix = "com.focusmaxxing.hub.download."

    // downloads alive in this process, by session identifier, and the system's "events
    // delivered" handlers waiting on them (see the AppDelegate extension at the bottom)
    private static let registryLock = NSLock()
    private static var live: [String: FMXBackgroundDownload] = [:]
    private static var eventHandlers: [String: () -> Void] = [:]

    private let identifier: String
    private let onProgress: (Int64, Int64) -> Void
    private var session: URLSession!

    // only touched on the session's own (serial) delegate queue
    private var continuation: CheckedContinuation<(URL, URLResponse?), Error>?
    private var downloadedFileURL: URL?
    private var moveError: Error?

    // onProgress gets (bytes so far, bytes expected); expected is 0 or less when unknown
    init(onProgress: @escaping (Int64, Int64) -> Void) {
        self.identifier = FMXBackgroundDownload.identifierPrefix + UUID().uuidString
        self.onProgress = onProgress
        super.init()

        let configuration = URLSessionConfiguration.background(withIdentifier: self.identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }

    // downloads the file to a temporary place of ours and hands back that file and the response.
    // the caller owns the file afterwards.
    func download(from url: URL) async throws -> (URL, URLResponse?) {
        FMXBackgroundDownload.registryLock.lock()
        FMXBackgroundDownload.live[self.identifier] = self
        FMXBackgroundDownload.registryLock.unlock()

        defer {
            FMXBackgroundDownload.registryLock.lock()
            FMXBackgroundDownload.live[self.identifier] = nil
            let leftoverHandler = FMXBackgroundDownload.eventHandlers.removeValue(forKey: self.identifier)
            FMXBackgroundDownload.registryLock.unlock()
            if let leftoverHandler {
                DispatchQueue.main.async(execute: leftoverHandler)
            }
            self.session.finishTasksAndInvalidate()
        }

        let task = self.session.downloadTask(with: url)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse?), Error>) in
                self.continuation = continuation
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    // the system's call when a download's events arrive while the hub is not in the foreground
    static func handleEvents(for identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier.hasPrefix(identifierPrefix) else {
            completionHandler()
            return
        }

        registryLock.lock()
        let isLive = live[identifier] != nil
        if isLive {
            eventHandlers[identifier] = completionHandler
        }
        registryLock.unlock()

        if !isLive {
            // the install this download belonged to is gone (the hub was closed fully); there is
            // nothing to finish, so let the system know straight away
            debugLog("[FMXBackgroundDownload] events for a download no install is waiting on: \(identifier)")
            completionHandler()
        }
    }

    /* URLSessionDownloadDelegate */

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        self.onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // the file at location is deleted as soon as this returns; move it somewhere of ours first
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".download")
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            self.downloadedFileURL = destination
        } catch {
            self.moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else if let moveError = self.moveError {
            continuation.resume(throwing: moveError)
        } else if let fileURL = self.downloadedFileURL {
            continuation.resume(returning: (fileURL, task.response))
        } else {
            continuation.resume(throwing: URLError(.cannotCreateFile))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // ios woke the hub for this download; tell it we are done with the events
        FMXBackgroundDownload.registryLock.lock()
        let handler = FMXBackgroundDownload.eventHandlers.removeValue(forKey: self.identifier)
        FMXBackgroundDownload.registryLock.unlock()
        guard let handler else { return }
        DispatchQueue.main.async(execute: handler)
    }
}

extension AppDelegate {
    // ios calls this when a background download finished while the hub was not in the
    // foreground (or after relaunching the hub for it)
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        FMXBackgroundDownload.handleEvents(for: identifier, completionHandler: completionHandler)
    }
}
