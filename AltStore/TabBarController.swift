//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//
//  focusmaxxing hub: four tabs instead of SideStore's five. News and Sources are gone,
//  Browse is pinned to the built-in app list (the two custom apps), and a switches
//  screen of our own comes first. My Apps and Settings are SideStore's, from the storyboard.
//

@preconcurrency import UIKit

extension TabBarController
{
    private enum Tab: Int, CaseIterable
    {
        case switches
        case apps
        case myApps
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

        guard let storyboardTabs = self.viewControllers, storyboardTabs.count > StoryboardTab.settings.rawValue else { return }

        let switchesNavigationController = ForwardingNavigationController(rootViewController: FMXSwitchesViewController())
        switchesNavigationController.tabBarItem = UITabBarItem(title: "Switches", image: UIImage(systemName: "switch.2"), tag: Tab.switches.rawValue)

        let appsNavigationController = ForwardingNavigationController(rootViewController: self.makeAppsViewController())
        appsNavigationController.tabBarItem = UITabBarItem(title: "Apps", image: UIImage(systemName: "square.grid.2x2"), tag: Tab.apps.rawValue)

        self.viewControllers = [switchesNavigationController,
                                appsNavigationController,
                                storyboardTabs[StoryboardTab.myApps.rawValue],
                                storyboardTabs[StoryboardTab.settings.rawValue]]
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

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}
