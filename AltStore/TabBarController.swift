//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//
//  focusmaxxing hub: three tabs instead of SideStore's five. News and Sources are gone,
//  Browse is pinned to the built-in app list (the two custom apps), and a switches
//  screen of our own comes first. Settings is SideStore's, from the storyboard, and so is the
//  list of installed apps - which since 2026-09-08 is not a tab but a screen the Apps tab pushes.
//

@preconcurrency import UIKit

extension TabBarController
{
    // three tabs since 2026-09-08. "Apps" and "My apps" were two tabs showing the same two apps and
    // the owner could not tell them apart; the list of installed apps is now reached from a button
    // on the Apps tab instead, and the days-left countdown that only lived over there is drawn on
    // the Apps tab's own tiles. Nothing was removed - see FMXInstalledApps in BrowseViewController.
    private enum Tab: Int, CaseIterable
    {
        case switches
        case apps
        case settings
    }

    // where the storyboard keeps SideStore's own tabs
    private enum StoryboardTab: Int
    {
        case news
        case sources
        case browse
        case myApps
        case settings
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?

    private var _viewDidAppear = false
    private var firstRunPresented = false

    // a file handed to the hub before the tabs were built, held until they are
    private var pendingImportURL: URL?

    // the accent behind the selected tab; iOS draws a grey capsule of its own and this is the
    // product's own shape instead. see FMXTabPill.
    private let tabPill = FMXTabPill()

    // whether the pill is currently behind the selected tab. the selected tab's drawing and word
    // are the dark ink that goes on the accent, which can only be read when the pill is there, so
    // the two are always changed together. it starts false, which is what viewDidLoad sets the bar
    // up for, so nothing is written twice before the first layout.
    private var pillShown = false

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)

        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")

        // the accent pill is not on the bar yet, so the selected tab is drawn in the accent
        // itself until showPill says otherwise
        FMXTheme.style(tabBar: self.tabBar, selectedOnAccent: false)

        guard let storyboardTabs = self.viewControllers, storyboardTabs.count > StoryboardTab.settings.rawValue else { return }

        let switchesNavigationController = ForwardingNavigationController(rootViewController: FMXSwitchesViewController())
        switchesNavigationController.tabBarItem = UITabBarItem(title: "Switches", image: UIImage(systemName: "switch.2"), tag: Tab.switches.rawValue)

        let appsNavigationController = ForwardingNavigationController(rootViewController: self.makeAppsViewController())
        appsNavigationController.tabBarItem = UITabBarItem(title: "Apps", image: UIImage(systemName: "square.grid.2x2"), tag: Tab.apps.rawValue)

        let settingsTab = storyboardTabs[StoryboardTab.settings.rawValue]

        // the tab that comes from the storyboard still wears the drawing the store this is forked
        // from used; ours are apple's own symbols, and tabs in two different families read as a
        // mistake. asked for by name so a name apple has moved simply leaves the old drawing in
        // place rather than an empty tab.
        if let image = UIImage(systemName: "gearshape") { settingsTab.tabBarItem.image = image }

        // the storyboard's My apps tab is deliberately left out of this list. its screen is still
        // built from the same storyboard scene, pushed from the Apps tab (see FMXInstalledApps).
        self.viewControllers = [switchesNavigationController,
                                appsNavigationController,
                                settingsTab]

        // ours goes on last so it is above the bar's own background and below the drawings
        self.tabBar.addSubview(self.tabPill)
        self.delegate = self
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.placeTabPill(animated: false)
    }

    override var selectedIndex: Int {
        didSet { self.placeTabPill(animated: true) }
    }

    override var selectedViewController: UIViewController? {
        didSet { self.placeTabPill(animated: true) }
    }

    /// show or hide the pill, and colour the selected tab to match.
    ///
    /// without this a bar the pill could not be placed on would draw its selected tab in near-black
    /// on near-black - the tab would simply vanish. the appearance is only written when the answer
    /// really changes, because assigning one makes the bar lay its buttons out again and this is
    /// called from every layout pass.
    private func showPill(_ shown: Bool)
    {
        guard self.pillShown != shown else { return }
        self.pillShown = shown
        self.tabPill.isHidden = !shown
        FMXTheme.style(tabBar: self.tabBar, selectedOnAccent: shown)
    }

    /// put the accent pill behind whichever tab is selected.
    ///
    /// the items of a tab bar are its only controls - the background behind them is not one - so
    /// they can be found without naming a single private class. if that ever stops being true the
    /// count will not match and the pill simply hides, which looks like the bar iOS draws rather
    /// than like something broken.
    private func placeTabPill(animated: Bool)
    {
        let items = self.tabBar.subviews.compactMap { $0 as? UIControl }.sorted { $0.frame.minX < $1.frame.minX }

        guard items.count == (self.viewControllers?.count ?? 0),
              items.indices.contains(self.selectedIndex),
              !items[self.selectedIndex].frame.isEmpty
        else {
            self.showPill(false)
            return
        }

        // the pill has to sit above the bar's own background and below every drawing and word, so
        // it goes directly under the lowest of the item buttons. asked for by neighbour rather than
        // by number: an index works out differently depending on whether the pill is already in the
        // list, and a version of this that inserted at a number swapped the pill above and below
        // the first button on alternate layout passes - which drew it over the Switches tab, the
        // one the app opens on.
        let bar = self.tabBar.subviews
        if let firstItem = bar.firstIndex(where: { $0 is UIControl }),
           (bar.firstIndex(of: self.tabPill) ?? Int.max) > firstItem
        {
            self.tabBar.insertSubview(self.tabPill, belowSubview: bar[firstItem])
        }
        self.showPill(true)

        let inset = FMXTabPill.inset
        let target = items[self.selectedIndex].frame.inset(by: inset)

        guard animated, !self.tabPill.frame.isEmpty, FMXTheme.animationsWanted else {
            self.tabPill.frame = target
            return
        }

        UIView.animate(withDuration: 0.22, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.tabPill.frame = target
        }
    }

    // the two tiles: SideStore's Browse screen, showing only the built-in source
    private func makeAppsViewController() -> UIViewController
    {
        let source = Source.fetchAltStoreSource(in: DatabaseManager.shared.viewContext)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let browseViewController = storyboard.instantiateViewController(identifier: "browseViewController") { coder in
            BrowseViewController(source: source, coder: coder)
        }
        browseViewController.title = "Apps"
        return browseViewController
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")

        _viewDidAppear = true

        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }

        // a file that arrived before the tabs were real
        if let url = self.pendingImportURL
        {
            self.pendingImportURL = nil
            NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil,
                                            userInfo: [AppDelegate.importAppDeepLinkURLKey: url])
        }

        self.presentFirstRunIfNeeded()
    }

    // focusmaxxing hub: the five setup steps, shown once. a moment's delay so it never collides
    // with a prompt the launch screen may be putting up at the same time.
    private func presentFirstRunIfNeeded()
    {
        guard !UserDefaults.standard.fmxFirstRunDone, !self.firstRunPresented else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self, !UserDefaults.standard.fmxFirstRunDone, !self.firstRunPresented else { return }
            guard self.presentedViewController == nil, self.parent?.presentedViewController == nil else {
                self.presentFirstRunIfNeeded()
                return
            }

            self.firstRunPresented = true
            let firstRun = FMXFirstRunViewController()
            firstRun.completion = { [weak self] in
                self?.selectedIndex = Tab.apps.rawValue
            }
            self.present(firstRun, animated: true)
        }
    }

    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }

        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    // focusmaxxing hub: there is no sources tab and no way to add a source (the free tier is the two
    // built-in apps). a "source" link or a "sources failed to load" toast just shows the app list.
    @objc func presentSources(_ sender: Any)
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }

            return
        }

        self.selectedIndex = Tab.apps.rawValue
    }
}

extension TabBarController: UITabBarControllerDelegate
{
    // a tap does not go through the selectedIndex setter, so the pill is told both ways
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
    {
        self.placeTabPill(animated: true)
    }
}

private extension TabBarController
{
    // a file handed to the hub from outside lands on the list of what is installed, which is where
    // the dialog that asks about it puts itself. that screen is no longer a tab, so the Apps tab is
    // opened first and the screen pushed on top of it.
    @objc func importApp(_ notification: Notification)
    {
        // on a cold launch a file can arrive before this screen has swapped the storyboard's five
        // tabs for our three - index 1 would then be a tab that is about to be thrown away, and the
        // dialog with it. it is kept until the tabs are real, the same way an early segue is.
        guard self._viewDidAppear else {
            self.pendingImportURL = notification.userInfo?[AppDelegate.importAppDeepLinkURLKey] as? URL
            return
        }

        self.selectedIndex = Tab.apps.rawValue

        guard let navigationController = self.selectedViewController as? UINavigationController,
              let root = navigationController.viewControllers.first
        else { return }

        let alreadyOpen = navigationController.viewControllers.contains { $0 is MyAppsViewController }
        FMXInstalledApps.show(from: root)

        // when that screen was a tab it existed from launch and heard about the file itself. it is
        // built when it is opened now, so the first time round it was not listening yet - the file
        // is announced again once it is on the pile. the second announcement finds it already open
        // and stops there, so this cannot go round twice.
        guard !alreadyOpen,
              let url = notification.userInfo?[AppDelegate.importAppDeepLinkURLKey] as? URL
        else { return }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil,
                                            userInfo: [AppDelegate.importAppDeepLinkURLKey: url])
        }
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}
