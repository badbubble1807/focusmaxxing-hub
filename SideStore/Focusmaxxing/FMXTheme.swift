//
//  FMXTheme.swift
//  Focusmaxxing Hub
//
//  the look of the phone screens, written down once.
//
//  focusmaxxing has one design system and it lives in theme.css at the top of the desktop
//  repository: two themes (dark is the default), one accent that means blocked / on / go, a
//  second one that means the wait, and a small set of shapes. the extension popup and the
//  windows app already wear it. this file is the same tokens in swift, so the phone cannot
//  drift away from the other two.
//
//  every colour below is a value out of theme.css, named the same way, so a change there can be
//  followed here by hand. the phone is dark only: the app asks for it in Info.plist
//  (UIUserInterfaceStyle), because a design that is drawn for one ground and shown on the other
//  looks like a mistake, and there is no theme picker on the phone to pick with.
//
//  what wears it: FMXControls.swift (the switch, the buttons, the rows), the switches screen, the
//  adult screen and the first run. the store's own screens - apps, my apps, settings - are
//  SideStore's, and they follow through the colours in the asset catalogue: Primary (the accent
//  everything is tinted with), Background and SettingsBackground (the ground).
//

import UIKit

enum FMXTheme {
    private static func rgb(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
        return UIColor(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    // MARK: the ground

    static let ink = rgb(7, 9, 15)              // --bg
    static let ink2 = rgb(13, 17, 27)           // --bg2
    static let card = rgb(17, 21, 32)           // --surface over the ground, as one solid colour
    static let cardLifted = rgb(24, 29, 42)     // a row under the finger
    static let hairline = UIColor(white: 1.0, alpha: 0.085)         // --border
    static let hairlineStrong = UIColor(white: 1.0, alpha: 0.18)    // --border-strong
    static let surfaceHigh = UIColor(white: 1.0, alpha: 0.13)       // --surface-3

    // MARK: the words

    static let text = rgb(243, 246, 255)                            // --text
    static var muted: UIColor { return FMXTheme.text.withAlphaComponent(0.62) }
    static var faint: UIColor { return FMXTheme.text.withAlphaComponent(0.4) }

    // MARK: volt - blocked, on, go

    static let volt = rgb(184, 255, 60)         // --ac1
    static let teal = rgb(52, 240, 201)         // --ac2
    static let sky = rgb(34, 199, 255)          // --ac3
    static let onInk = rgb(7, 16, 9)            // --on-ink, the dark words that sit on volt
    static let accentText = rgb(108, 245, 214)  // --accent-text

    // MARK: ember - the wait

    static let ember = rgb(255, 181, 61)        // --wait1
    static let emberDeep = rgb(255, 106, 31)    // --wait2
    static let waitInk = rgb(28, 10, 0)         // --wait-ink

    // MARK: the rest

    static let danger = rgb(255, 77, 109)       // --danger
    static let slate = rgb(92, 97, 107)         // nothing is blocked yet, and no claim is made

    // MARK: shapes

    static let radius: CGFloat = 20             // --radius
    static let radiusSmall: CGFloat = 14        // --radius-sm
    static let radiusTiny: CGFloat = 10         // --radius-xs

    /// how far in from the edge of the screen the words inside a card start: the inset grouped
    /// table pushes its cards in, and the card pushes its own contents in again. a heading laid
    /// out with this lines up with the rows underneath it.
    static let rowInset: CGFloat = 36

    // MARK: putting it on

    /// called once at launch. the hub has one colour, so anything a customer's phone remembers
    /// from before this fork (SideStore let people pick one) is put back to it.
    static func apply() {
        ThemeManager.shared.resetToDefault()
    }

    /// the bar at the bottom: the ink, the accent on what is selected.
    static func style(tabBar: UITabBar) {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = FMXTheme.ink.withAlphaComponent(0.86)
        appearance.shadowColor = FMXTheme.hairline

        // a badge is drawn on the accent, and a number written in white on a bright colour cannot
        // be read - the same rule the toasts follow
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.badgeTextAttributes = [.foregroundColor: FMXTheme.onInk]
            layout.selected.badgeTextAttributes = [.foregroundColor: FMXTheme.onInk]
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = FMXTheme.teal
        tabBar.unselectedItemTintColor = FMXTheme.faint
    }

    /// the bar at the top of one of our own screens: nothing until the list scrolls under it,
    /// then the ink with a hairline.
    static func style(navigationItem: UINavigationItem) {
        let title: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text]
        let largeTitle: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text,
                                                         .font: UIFont.systemFont(ofSize: 34, weight: .bold)]

        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.shadowColor = nil
        edge.titleTextAttributes = title
        edge.largeTitleTextAttributes = largeTitle
        edge.configureWithTintColor(FMXTheme.teal)

        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = FMXTheme.ink
        standard.shadowColor = FMXTheme.hairline
        standard.titleTextAttributes = title
        standard.largeTitleTextAttributes = largeTitle
        standard.configureWithTintColor(FMXTheme.teal)

        navigationItem.standardAppearance = standard
        navigationItem.compactAppearance = standard
        navigationItem.scrollEdgeAppearance = edge
    }

    /// a list on the ground, with no lines of its own: the cards are the shapes.
    static func style(tableView: UITableView) {
        tableView.backgroundColor = FMXTheme.ink
        tableView.backgroundView = FMXBackdropView()
        tableView.separatorColor = FMXTheme.hairline
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.sectionHeaderTopPadding = 6
    }

    /// the ink, with the accent glowing faintly behind the top of the screen. the same "ambient"
    /// the desktop app has behind its window.
    static func backdrop() -> UIView {
        return FMXBackdropView()
    }
}

/// a view that is nothing but a gradient. used for the switch's track, the big buttons and the
/// ground behind a screen.
class FMXGradientView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    var gradientLayer: CAGradientLayer {
        // safe: the class above is what the layer is made from
        return self.layer as! CAGradientLayer
    }

    init(colors: [UIColor], from: CGPoint = CGPoint(x: 0, y: 0), to: CGPoint = CGPoint(x: 1, y: 1)) {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        self.setColors(colors)
        self.gradientLayer.startPoint = from
        self.gradientLayer.endPoint = to
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setColors(_ colors: [UIColor]) {
        self.gradientLayer.colors = colors.map { $0.cgColor }
    }
}

/// the ground: ink, a touch lighter at the top, with the accent glowing behind the first part of
/// the screen. it is deliberately faint - it should read as depth, not as a coloured background.
final class FMXBackdropView: UIView {
    private let base = CAGradientLayer()
    private let glow = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = FMXTheme.ink

        self.base.colors = [FMXTheme.ink2.cgColor, FMXTheme.ink.cgColor]
        self.base.startPoint = CGPoint(x: 0.5, y: 0)
        self.base.endPoint = CGPoint(x: 0.5, y: 1)
        self.layer.addSublayer(self.base)

        self.glow.colors = [FMXTheme.teal.withAlphaComponent(0.13).cgColor,
                            FMXTheme.teal.withAlphaComponent(0).cgColor]
        self.glow.startPoint = CGPoint(x: 0.5, y: 0)
        self.glow.endPoint = CGPoint(x: 0.5, y: 1)
        self.layer.addSublayer(self.glow)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // layers of our own do not follow the view unless they are told to, and they animate
        // while they are being told unless that is switched off
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.base.frame = self.bounds
        self.glow.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: min(self.bounds.height, 340))
        CATransaction.commit()
    }
}
