//
//  FMXReminder.swift
//  Focusmaxxing Hub
//
//  the reminder from the checklist: a notification when an app has (by default) one day left and
//  the hub could not renew it by itself. there is no way to know in advance whether the helper will
//  connect, so the reminder is booked for "one day before the first app stops opening", and every
//  renewal books it again a week later. it only ever goes off when nothing renewed the app in time,
//  which from the outside is exactly "the helper could not connect". the number of days is chosen
//  in Settings (SettingsViewController, the Reminder section).
//
//  booked again at launch and when the hub comes to the front (AppManager.reconcileInstalledApps),
//  after every install, update, renewal or removal (PipelineRunner.performOperation), and when the
//  number of days changes.
//

import UserNotifications
import CoreData

extension UserDefaults {
    // days before an app stops opening; 1 to 6, one day unless changed
    @objc var fmxReminderDays: Int {
        get {
            let stored = self.integer(forKey: "fmxReminderDays")
            return stored == 0 ? 1 : min(max(stored, 1), FMXReminder.maxDays)
        }
        set { self.set(min(max(newValue, 1), FMXReminder.maxDays), forKey: "fmxReminderDays") }
    }
}

enum FMXReminder {
    static let notificationIdentifier = "fmx-reminder"
    static let maxDays = 6

    // the (app, expiry) a late booking was already made for, so opening the hub again and again
    // inside the window neither pushes the reminder out each time nor repeats it
    private static let lateBookingKey = "fmxReminderLateBooking"

    static func reschedule(in context: NSManagedObjectContext) {
        let days = UserDefaults.standard.fmxReminderDays
        let now = Date()

        // the first app to stop opening, among the ones that still open. the hub itself is left out:
        // SideStore already books its own warnings for the hub (ScheduleExpirationWarningNotificationOperation),
        // and a renewal of the hub restarts the process before this could book again, which would leave a
        // stale reminder behind
        var soonestBundleID: String?
        var soonestName: String?
        var soonestExpiry: Date?
        context.performAndWait {
            let apps = InstalledApp.fetchActiveApps(in: context).filter {
                $0.bundleIdentifier != StoreApp.altstoreAppID && $0.expirationDate > now
            }
            guard let first = apps.min(by: { $0.expirationDate < $1.expirationDate }) else { return }
            soonestBundleID = first.bundleIdentifier
            soonestName = first.name
            soonestExpiry = first.expirationDate
        }

        let center = UNUserNotificationCenter.current()
        guard let bundleID = soonestBundleID, let name = soonestName, let expiry = soonestExpiry else {
            center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
            debugLog("[FMXReminder] no custom app installed that still opens; no reminder booked")
            return
        }

        // already inside the window (the hub was opened late): remind in an hour, once for this expiry.
        // a renewal moves the expiry a week out and books normally again, which replaces this.
        var fireDate = expiry.addingTimeInterval(-Double(days) * 24 * 60 * 60)
        var isLate = false
        if fireDate <= now {
            let key = "\(bundleID)|\(Int(expiry.timeIntervalSince1970))"
            guard UserDefaults.standard.string(forKey: lateBookingKey) != key else {
                debugLog("[FMXReminder] inside the window and already reminded once for \(name); leaving it")
                return
            }
            UserDefaults.standard.set(key, forKey: lateBookingKey)
            fireDate = now.addingTimeInterval(60 * 60)
            isLate = true
        }
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])

        let content = UNMutableNotificationContent()
        if isLate {
            content.title = "\(name) stops opening soon"
        } else {
            content.title = days == 1 ? "\(name) stops opening in 1 day" : "\(name) stops opening in \(days) days"
        }
        content.body = "Focusmaxxing Hub could not renew it by itself. Open the Hub with the helper on and it will."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(fireDate.timeIntervalSince(now), 1), repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        center.add(request) { error in
            if let error {
                debugLog("[FMXReminder] could not book the reminder: \(error)")
            }
        }
        debugLog("[FMXReminder] reminder booked for \(fireDate): \(name) stops opening \(expiry), \(days) day(s) before")
    }
}
