//
//  FMXInstalledApps.swift
//  Focusmaxxing Hub
//
//  the screen that lists what is installed, and the one way in to it.
//
//  until 2026-09-08 this was a tab of its own called "My apps", sitting next to a tab called "Apps"
//  and showing the same two apps. the owner asked three times what the difference was, which is the
//  answer: there wasn't one worth a tab. so the Apps tab now carries the two things only this
//  screen used to have - how many days each app has left, and Refresh all - and this screen is
//  reached from a button on it, for the rest: turning an app off to make room, removing one,
//  backups, and the updates list.
//
//  nothing about it was rewritten. it is the same storyboard scene, the same MyAppsViewController,
//  with the same confirming alerts on everything that removes an app; it is pushed instead of being
//  a tab. that is deliberate - the countdown and the renew button are the customer's only warning
//  that an app is about to stop opening, and a rewrite is how a warning gets lost.
//

import UIKit

enum FMXInstalledApps {
    /// what the screen is called now. "My apps" said nothing next to a tab called "Apps".
    static let title = "Installed"

    /// a fresh copy of the storyboard's own My apps screen.
    ///
    /// it is built from the scene rather than lifted out of the tab bar's copy so that every segue
    /// defined on that scene - the App IDs one, and the unwind that comes back from it - still has
    /// the storyboard's own controller to work with.
    static func make() -> UIViewController? {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let screen = storyboard.instantiateViewController(withIdentifier: "myAppsViewController") as? MyAppsViewController else {
            debugLog("[FMXInstalledApps] the storyboard has no myAppsViewController")
            return nil
        }

        screen.title = FMXInstalledApps.title
        screen.navigationItem.title = FMXInstalledApps.title
        // the large title is what the green/red helper dot hangs off, and the Apps tab underneath
        // deliberately has none of its own
        screen.navigationItem.largeTitleDisplayMode = .always
        FMXTheme.style(navigationItem: screen.navigationItem)
        return screen
    }

    /// open it from wherever the customer is. a screen already on the pile is come back to rather
    /// than stacked on itself, which is what a second tap on the button would otherwise do.
    static func show(from viewController: UIViewController) {
        guard let navigationController = viewController.navigationController else { return }

        if let existing = navigationController.viewControllers.first(where: { $0 is MyAppsViewController }) {
            navigationController.popToViewController(existing, animated: true)
            return
        }

        guard let screen = FMXInstalledApps.make() else { return }

        // asking a screen for a large title does nothing unless the bar it lands on wants them, and
        // the Apps tab's bar is built in code, where they are off. the switches screen sets the same
        // pair. the Apps list underneath is unaffected: it asks for .never itself.
        navigationController.navigationBar.prefersLargeTitles = true
        navigationController.pushViewController(screen, animated: true)
    }
}
