//
//  FMXLeftoverSources.swift
//  Focusmaxxing Hub
//
//  a hub installed over SideStore inherits SideStore's own source (sidestore.io/apps-v2.json)
//  in the database. the hub has no sources screen, so it sat there for good: it failed to load
//  at every launch (the "Some sources were unable to load" toast, after a three-second wait)
//  and it held a second entry for the hub's own bundle id, which is where the hub's installed
//  record pointed, so the hub never offered itself an update from our list.
//
//  the free tier is our list and nothing else, so every other source is removed at every
//  launch, from DatabaseManager.prepareDatabase, with any installed app that pointed at one of
//  its entries moved over to the same app in our list first (or to no entry, which SideStore
//  treats as a sideloaded app).
//

import CoreData

enum FMXLeftoverSources {
    static func remove(keeping ownSource: Source, in context: NSManagedObjectContext) {
        let predicate = NSPredicate(format: "%K != %@", #keyPath(Source.identifier), ownSource.identifier)
        let leftovers = Source.all(satisfying: predicate, in: context)
        guard !leftovers.isEmpty else { return }

        for source in leftovers {
            for app in source.apps {
                guard let installedApp = app.installedApp else { continue }
                let replacement = ownSource.apps.first { $0.bundleIdentifier == app.bundleIdentifier }
                installedApp.storeApp = replacement
                debugLog("[FMXLeftoverSources] \(app.bundleIdentifier) pointed at the leftover source; now at \(replacement == nil ? "no entry" : "our list")")
            }
            debugLog("[FMXLeftoverSources] removing leftover source \(source.identifier) (\(source.sourceURL.absoluteString))")
            context.delete(source)
        }
    }
}
