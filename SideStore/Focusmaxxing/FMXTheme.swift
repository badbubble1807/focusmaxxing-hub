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

    /// how far in a heading's words start from the edge of its own view. the table gives a section
    /// heading the same width as the cards below it - both are already pushed in from the screen -
    /// so all that is left to match is the margin the card puts round its own contents.
    static let rowInset: CGFloat = 16

    // MARK: movement

    /// whether this phone wants things to move. everything that drifts, breathes, springs or
    /// staggers asks this first; somebody who has turned motion off in Accessibility gets the same
    /// screen standing still, never a screen with pieces missing.
    static var animationsWanted: Bool {
        return !UIAccessibility.isReduceMotionEnabled
    }

    /// light pooled under something, rather than a ring drawn round it.
    ///
    /// this is the one shape every glowing thing in the product shares - `0 <y>px <blur>px
    /// -<spread>px <colour>` in the stylesheets both of the owner's other apps use. two things have
    /// to be translated rather than copied: a css blur is about twice the radius core animation
    /// takes, so it is halved here; and a layer has no idea what a shadow spread is, so a negative
    /// spread has to be drawn as a shadow cast by a smaller shape - which is exactly what makes the
    /// light pool underneath instead of haloing all the way round.
    static func glow(on layer: CALayer, bounds: CGRect, radius corner: CGFloat,
                     colour: UIColor, y: CGFloat, blur: CGFloat, spread: CGFloat, opacity: Float) {
        layer.shadowColor = colour.cgColor
        layer.shadowOffset = CGSize(width: 0, height: y)
        layer.shadowRadius = blur / 2
        layer.shadowOpacity = opacity

        let shape = bounds.insetBy(dx: spread, dy: spread)
        guard !shape.isEmpty else {
            layer.shadowPath = nil
            return
        }
        layer.shadowPath = UIBezierPath(roundedRect: shape, cornerRadius: max(1, corner - spread)).cgPath
    }

    // MARK: putting it on

    /// called once at launch. the hub has one colour, so anything a customer's phone remembers
    /// from before this fork (SideStore let people pick one) is put back to it; and Manrope is
    /// made sure of before the first screen is drawn.
    static func apply() {
        ThemeManager.shared.resetToDefault()
        FMXFont.registerIfNeeded()
    }

    /// the bar at the bottom: the ink, the accent on what is selected.
    ///
    /// `selectedOnAccent` says whether the accent pill (FMXTabPill) is really behind the selected
    /// tab. when it is, that tab's drawing and word are the dark ink that always goes on the accent;
    /// when it is not - a bar this app could not place the pill on - they are the accent itself, so
    /// the selected tab is still the one that stands out rather than the one that disappeared.
    static func style(tabBar: UITabBar, selectedOnAccent: Bool = true) {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = FMXTheme.ink.withAlphaComponent(0.86)
        appearance.shadowColor = FMXTheme.hairline

        // the pill behind the selected tab is ours (FMXTabPill), so whatever iOS would have drawn
        // there is made invisible rather than left to sit underneath it. on the iPhone before iOS 26
        // it drew nothing here anyway, so this only matters where it does.
        appearance.selectionIndicatorTintColor = .clear

        // a badge is drawn on the accent, and a number written in white on a bright colour cannot
        // be read - the same rule the toasts follow. the labels are Manrope like everything else.
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.badgeTextAttributes = [.foregroundColor: FMXTheme.onInk]
            layout.selected.badgeTextAttributes = [.foregroundColor: FMXTheme.onInk]
            layout.normal.titleTextAttributes = [.font: FMXFont.of(10, .semibold), .foregroundColor: FMXTheme.faint]

            // the selected tab sits on the accent pill FMXTabPill draws, so its word and its
            // drawing are the dark ink that goes on the accent everywhere else in the product.
            // teal on volt cannot be read.
            let chosen = selectedOnAccent ? FMXTheme.onInk : FMXTheme.volt
            layout.selected.titleTextAttributes = [.font: FMXFont.of(10, .bold), .foregroundColor: chosen]
            layout.normal.iconColor = FMXTheme.faint
            layout.selected.iconColor = chosen
        }

        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = FMXTheme.teal
        tabBar.unselectedItemTintColor = FMXTheme.faint
    }

    /// the bar at the top of one of our own screens: nothing until the list scrolls under it,
    /// then the ink with a hairline.
    static func style(navigationItem: UINavigationItem) {
        // 28 rather than the system's 34: the longest title on the phone is "Focusmaxxing mobile",
        // and a large title does not shrink to fit - it simply runs out of bar and truncates
        let title: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text,
                                                    .font: FMXFont.of(17, .bold)]
        let largeTitle: [NSAttributedString.Key: Any] = [.foregroundColor: FMXTheme.text,
                                                         .font: FMXFont.of(28, .heavy)]

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

/// the ground: ink, a touch lighter at the top, with three soft pools of accent light drifting
/// slowly behind everything.
///
/// this is the owner's other iPhone app - Bubble Alarm - which does it in one stylesheet: three
/// round radial gradients, one per accent, far bigger than the screen and mostly hanging off the
/// edges of it, each drifting on a slow loop of its own so they never march in step. the colours
/// are ours, not its (volt, teal, sky rather than its purples), which is exactly what the owner
/// asked for: the light and the shapes from that app, the colours from this one.
///
/// the one thing that could not be brought over is its 90px blur. iOS has no public way to blur a
/// layer, and a radial gradient that has already faded out well before its own edge reads the same,
/// so the blur is simply left out rather than faked with private calls.
///
/// every screen gets this for free: `FMXTheme.backdrop()` and `FMXTheme.style(tableView:)` are the
/// only two ways a screen asks for a ground, and both make one of these.
final class FMXBackdropView: UIView {
    /// one blob: how big it is and where it sits, both as a fraction of the longer side of the
    /// screen, plus how long it takes to drift once round. taken straight across from `.b1 .b2 .b3`
    /// (the css is in vmax, which is that same longer side).
    private struct Blob {
        let size: CGFloat
        let centre: CGPoint      // where the middle of the circle sits, from the top left
        let colour: UIColor
        let strength: Float
        let seconds: CFTimeInterval
        let head: CFTimeInterval // how far into its own loop it starts, so three never line up
    }

    private static let blobs: [Blob] = [
        Blob(size: 0.56, centre: CGPoint(x: 0.005, y: 0.000), colour: FMXTheme.volt, strength: 0.28, seconds: 22, head: 0),
        Blob(size: 0.50, centre: CGPoint(x: 0.805, y: 0.330), colour: FMXTheme.teal, strength: 0.22, seconds: 28, head: 8),
        Blob(size: 0.46, centre: CGPoint(x: 0.975, y: 1.030), colour: FMXTheme.sky, strength: 0.18, seconds: 26, head: 15),
    ]

    private let base = CAGradientLayer()
    private var pools = [CAGradientLayer]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = FMXTheme.ink
        self.isUserInteractionEnabled = false

        self.base.colors = [FMXTheme.ink2.cgColor, FMXTheme.ink.cgColor]
        self.base.startPoint = CGPoint(x: 0.5, y: 0)
        self.base.endPoint = CGPoint(x: 0.5, y: 1)
        self.layer.addSublayer(self.base)

        for blob in FMXBackdropView.blobs {
            let pool = CAGradientLayer()
            pool.type = .radial
            pool.colors = [blob.colour.cgColor, blob.colour.withAlphaComponent(0).cgColor]
            // the middle of the circle, and how far out it has faded to nothing. the stylesheet
            // says "transparent 62%", measured to the far corner of its own box.
            pool.startPoint = CGPoint(x: 0.5, y: 0.5)
            pool.endPoint = CGPoint(x: 0.94, y: 0.94)
            pool.opacity = blob.strength
            self.layer.addSublayer(pool)
            self.pools.append(pool)
        }

        self.drift()

        // an animation is taken off a layer when the app goes away, and is not put back by itself.
        // without this the ground is alive until the first trip to the home screen and still
        // afterwards, which looks like something broke.
        NotificationCenter.default.addObserver(self, selector: #selector(drift),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // layers of our own do not follow the view unless they are told to, and they animate
        // while they are being told unless that is switched off
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.base.frame = self.bounds

        // the stylesheet measures every blob against the longer side of the screen, so the same
        // numbers give the same picture on a small phone and a large one
        let long = max(self.bounds.width, self.bounds.height)
        for (pool, blob) in zip(self.pools, FMXBackdropView.blobs) {
            let side = long * blob.size
            pool.frame = CGRect(x: (self.bounds.width * blob.centre.x) - (side / 2),
                                y: (self.bounds.height * blob.centre.y) - (side / 2),
                                width: side, height: side)
        }
        CATransaction.commit()
    }

    /// the slow wander. it never stops and never changes anything a finger can reach, so the only
    /// reason to leave it out is somebody having asked for less movement.
    ///
    /// the stylesheet's own step is `translate3d(6vmax, 4vmax, 0) scale(1.12)` over 22 to 28
    /// seconds, going back the way it came rather than jumping.
    @objc private func drift() {
        let long = max(self.bounds.width, self.bounds.height, UIScreen.main.bounds.height)
        let step = CATransform3DMakeTranslation(long * 0.06, long * 0.04, 0)
        let end = CATransform3DScale(step, 1.12, 1.12, 1)

        for (pool, blob) in zip(self.pools, FMXBackdropView.blobs) {
            pool.removeAnimation(forKey: "fmxDrift")
            guard FMXTheme.animationsWanted else { continue }

            let move = CABasicAnimation(keyPath: "transform")
            move.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            move.toValue = NSValue(caTransform3D: end)
            move.duration = blob.seconds
            move.autoreverses = true
            move.repeatCount = .infinity
            move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            move.timeOffset = blob.head
            pool.add(move, forKey: "fmxDrift")
        }
    }
}
