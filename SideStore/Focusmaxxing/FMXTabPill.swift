//
//  FMXTabPill.swift
//  Focusmaxxing Hub
//
//  the accent pill behind whichever tab is selected.
//
//  the owner's other iPhone app draws its selected tab as the accent gradient with the accent
//  pooled underneath (`.tab-btn.active`: a 18px corner, a 135 degree gradient, and
//  `0 10px 26px -8px` of its own colour below it). iOS draws a plain grey capsule instead, which is
//  what the owner's screenshot showed and what made the bar the last piece of the phone that did
//  not belong to this product.
//
//  it is a view rather than a picture handed to UITabBar, because the one property iOS offers for
//  this (`selectionIndicatorTintColor`) takes a single flat colour: no gradient and no glow.
//
//  it is placed by TabBarController, which is the only thing that knows which item is selected and
//  where that item's own drawing sits.
//

import UIKit

final class FMXTabPill: UIView {
    /// `.tab-btn` border-radius: 18px
    private static let radius: CGFloat = 18

    /// how much smaller than its item's own box the pill is drawn, so two neighbouring pills could
    /// never touch and the words keep their air
    static let inset = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)

    private let gradient = FMXGradientView(colors: [FMXTheme.volt, FMXTheme.teal])

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false

        self.gradient.layer.masksToBounds = true
        self.addSubview(self.gradient)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()

        let corner = min(FMXTabPill.radius, self.bounds.height / 2)
        self.gradient.frame = self.bounds
        self.gradient.layer.cornerRadius = corner
        self.gradient.layer.cornerCurve = .continuous

        // the glow goes on this view's own layer rather than on the gradient: the gradient clips
        // its corners, and a layer that clips cannot cast a shadow outside itself. the same note as
        // the switch in FMXControls.swift.
        //
        // the y offset is a whisper UP (-2), not down. everywhere else in the product the pooled
        // light sits below its shape, because those shapes have room below them. this one does not:
        // it is at the very bottom of the screen, a hair above the home indicator, so a downward
        // offset (this was y:10 once) pushes the light off the bottom edge, where it is clipped and
        // reads as a blob chopped off under the leftmost tab - the one the app opens on. pooling it
        // up instead keeps the whole glow inside the bar, over the ink, where there is room for it.
        FMXTheme.glow(on: self.layer, bounds: self.bounds, radius: corner,
                      colour: FMXTheme.volt, y: -2, blur: 26, spread: 8, opacity: 0.55)
    }
}
