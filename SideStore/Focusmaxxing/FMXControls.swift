//
//  FMXControls.swift
//  Focusmaxxing Hub
//
//  the pieces the phone screens are built out of, all wearing FMXTheme.
//
//  the one that matters is FMXSwitchView. it is the same control as the switch in the desktop app
//  and the extension popup, drawn from the same numbers (theme.css, `.sw`): a 52 by 30 track with
//  a 22 point knob that slides 22 points. blocked is the volt gradient with the knob to the right,
//  allowed is a plain grey track with the knob to the left, and the wait is the ember gradient
//  with the seconds counting down in the space the knob left behind. it does not say on or off
//  anywhere: the colour and the side the knob is on are the state, exactly as on the other two
//  screens of this product.
//
//  why it is a control and not a picture: the row it sits in is tappable too, and the two must not
//  both fire. a control swallows the touch that lands on it, so the pill sends one tap and the
//  rest of the row sends the other.
//

import UIKit

/// what a switch is doing. the wait lives here, not in the store: leaving the screen throws it
/// away on purpose, so it can never be sat through in the background.
enum FMXPhase {
    case off             // allowed; a tap blocks, instantly
    case on              // blocked; a tap starts the wait
    case counting(Int)   // waiting; taps are ignored
    case armed           // the wait is up; a tap unblocks
}

// MARK: - the switch

final class FMXSwitchView: UIControl {
    static let width: CGFloat = 52
    static let height: CGFloat = 30

    private static let knob: CGFloat = 22
    private static let inset: CGFloat = 4
    private static let travel: CGFloat = FMXSwitchView.width - FMXSwitchView.knob - (FMXSwitchView.inset * 2)

    private let track = FMXGradientView(colors: [FMXTheme.surfaceHigh, FMXTheme.surfaceHigh])
    private let knobView = UIView()
    private let numberLabel = UILabel()

    // what is on screen now, so the knob only slides when the state really changed and not four
    // times a second while a countdown runs
    private var shownKind = ""

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: FMXSwitchView.width, height: FMXSwitchView.height))

        self.track.frame = self.bounds
        self.track.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.track.layer.cornerRadius = FMXSwitchView.height / 2
        self.track.layer.masksToBounds = true
        self.track.layer.borderWidth = 1
        self.track.layer.borderColor = FMXTheme.hairline.cgColor
        self.addSubview(self.track)

        // the seconds sit in the half the knob is not in
        self.numberLabel.frame = CGRect(x: 0, y: 0, width: 28, height: FMXSwitchView.height)
        self.numberLabel.textAlignment = .center
        self.numberLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .heavy)
        self.numberLabel.textColor = FMXTheme.waitInk
        self.numberLabel.isUserInteractionEnabled = false
        self.addSubview(self.numberLabel)

        self.knobView.frame = CGRect(x: FMXSwitchView.inset, y: FMXSwitchView.inset,
                                     width: FMXSwitchView.knob, height: FMXSwitchView.knob)
        self.knobView.backgroundColor = .white
        self.knobView.layer.cornerRadius = FMXSwitchView.knob / 2
        self.knobView.layer.shadowColor = UIColor.black.cgColor
        self.knobView.layer.shadowOpacity = 0.35
        self.knobView.layer.shadowRadius = 3
        self.knobView.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.knobView.isUserInteractionEnabled = false
        self.addSubview(self.knobView)

        // the glow goes on this view's own layer: the track clips its corners, and anything
        // clipped cannot cast a shadow outside itself
        self.layer.shadowColor = FMXTheme.volt.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 6)
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: FMXSwitchView.width, height: FMXSwitchView.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds,
                                             cornerRadius: FMXSwitchView.height / 2).cgPath
    }

    func show(_ phase: FMXPhase) {
        switch phase {
        case .off:
            self.numberLabel.text = ""
            self.set(kind: "off", colors: [FMXTheme.surfaceHigh, FMXTheme.surfaceHigh],
                     glow: nil, knobRight: false, outlined: true)
        case .on:
            self.numberLabel.text = ""
            self.set(kind: "on", colors: [FMXTheme.volt, FMXTheme.teal],
                     glow: FMXTheme.volt, knobRight: true, outlined: false)
        case .counting(let secondsLeft):
            self.numberLabel.text = "\(secondsLeft)"
            self.set(kind: "counting", colors: [FMXTheme.ember, FMXTheme.emberDeep],
                     glow: FMXTheme.emberDeep, knobRight: true, outlined: false)
        case .armed:
            self.numberLabel.text = ""
            self.set(kind: "armed", colors: [FMXTheme.ember, FMXTheme.emberDeep],
                     glow: FMXTheme.emberDeep, knobRight: true, outlined: false)
        }
    }

    /// grey and knob to the left, for a switch whose block has not been set up yet. green would be
    /// a claim that something is blocked when nothing is.
    func showNotSetUp() {
        self.numberLabel.text = ""
        self.set(kind: "notSetUp", colors: [FMXTheme.slate, FMXTheme.slate],
                 glow: nil, knobRight: false, outlined: true)
    }

    private func set(kind: String, colors: [UIColor], glow: UIColor?, knobRight: Bool, outlined: Bool) {
        guard kind != self.shownKind else { return }
        let firstTime = self.shownKind.isEmpty
        self.shownKind = kind

        self.track.setColors(colors)
        self.track.layer.borderColor = (outlined ? FMXTheme.hairline : UIColor.clear).cgColor

        if let glow = glow {
            self.layer.shadowColor = glow.cgColor
            self.layer.shadowOpacity = 0.55
        } else {
            self.layer.shadowOpacity = 0
        }

        let move = {
            self.knobView.transform = knobRight ? CGAffineTransform(translationX: FMXSwitchView.travel, y: 0) : .identity
        }
        if firstTime {
            // a screen opens already showing the state; it does not animate into it
            move()
        } else {
            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.62,
                           initialSpringVelocity: 0.4, options: [], animations: move, completion: nil)
        }

        // the wait breathes, so a countdown is visible from across a room
        self.layer.removeAnimation(forKey: "fmxPulse")
        if kind == "counting" || kind == "armed" {
            let pulse = CABasicAnimation(keyPath: "shadowOpacity")
            pulse.fromValue = 0.2
            pulse.toValue = 0.85
            pulse.duration = (kind == "counting") ? 0.55 : 0.85
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            self.layer.add(pulse, forKey: "fmxPulse")
        }
    }
}

// MARK: - the rows

/// every row of ours: a card on the ground, a shade lighter under the finger.
class FMXCell: UITableViewCell {
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        // the row's own default is the starting point where it can be had: it is the one that
        // knows where this row sits in its group, which is what rounds the top of the first row
        // and the bottom of the last. it only exists from iOS 16, so older phones get the plain
        // grouped-row default instead. either way only the colour is ours.
        var background: UIBackgroundConfiguration
        if #available(iOS 16.0, *) {
            background = self.defaultBackgroundConfiguration()
        } else {
            background = UIBackgroundConfiguration.listGroupedCell()
        }
        background.backgroundColor = (state.isHighlighted || state.isSelected) ? FMXTheme.cardLifted : FMXTheme.card
        self.backgroundConfiguration = background
    }
}

/// one switch: what it blocks on the left, the switch on the right.
final class FMXSwitchCell: FMXCell {
    let titleLabel = UILabel()
    let subLabel = UILabel()
    let statusLabel = UILabel()
    let pill = FMXSwitchView()
    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        self.titleLabel.textColor = FMXTheme.text

        self.subLabel.font = .systemFont(ofSize: 12.5, weight: .regular)
        self.subLabel.textColor = FMXTheme.muted
        self.subLabel.numberOfLines = 2

        self.statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        self.statusLabel.textColor = FMXTheme.ember
        self.statusLabel.textAlignment = .right
        self.statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.pill.addTarget(self, action: #selector(pillTapped), for: .touchUpInside)

        for view in [self.titleLabel, self.subLabel, self.statusLabel, self.pill] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.pill.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.pill.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.pill.widthAnchor.constraint(equalToConstant: FMXSwitchView.width),
            self.pill.heightAnchor.constraint(equalToConstant: FMXSwitchView.height),

            self.statusLabel.trailingAnchor.constraint(equalTo: self.pill.leadingAnchor, constant: -10),
            self.statusLabel.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 110),

            self.titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 13),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),

            self.subLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.subLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 3),
            self.subLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -13),
            self.subLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func pillTapped() { self.onTap?() }

    func showNotSetUp() {
        self.pill.showNotSetUp()
        self.statusLabel.text = ""
    }

    func show(_ phase: FMXPhase) {
        self.pill.show(phase)
        switch phase {
        case .armed: self.statusLabel.text = "Tap to unblock"
        case .off, .on, .counting: self.statusLabel.text = ""
        }
    }
}

// MARK: - the small pieces

/// the little word beside a heading: ALL BLOCKED, 5 OF 7, LOCKED. the desktop app has the same
/// badge on a site that has something blocked.
final class FMXChipView: UIView {
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        self.layer.cornerRadius = 9
        self.layer.masksToBounds = true

        self.label.font = .systemFont(ofSize: 10.5, weight: .heavy)
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.label)

        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            self.label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -8),
            self.label.topAnchor.constraint(equalTo: self.topAnchor, constant: 3),
            self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -3),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(_ text: String, colour: UIColor) {
        let wanted = text.uppercased()
        // the screen asks for this four times a second while a countdown runs; laying the chip
        // out again each time for the same words in the same colour is work nobody sees
        guard wanted != self.label.text || colour != self.label.textColor else { return }
        self.label.text = wanted
        self.label.textColor = colour
        self.backgroundColor = colour.withAlphaComponent(0.15)
        self.isHidden = text.isEmpty
    }
}

/// the heading over a group of rows, with room for a chip on the right.
final class FMXSectionHeader: UIView {
    static let height: CGFloat = 54

    private let titleLabel = UILabel()
    private let chip = FMXChipView()

    init(title: String) {
        super.init(frame: .zero)

        self.titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        self.titleLabel.textColor = FMXTheme.text
        self.titleLabel.text = title

        self.chip.isHidden = true

        // a heading built by hand is not a heading to VoiceOver unless it is told so; the plain
        // one this replaced was
        self.isAccessibilityElement = true
        self.accessibilityTraits = .header
        self.accessibilityLabel = title

        for view in [self.titleLabel, self.chip] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
        }

        NSLayoutConstraint.activate([
            self.titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: FMXTheme.rowInset),
            self.titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -10),

            self.chip.leadingAnchor.constraint(greaterThanOrEqualTo: self.titleLabel.trailingAnchor, constant: 10),
            self.chip.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -FMXTheme.rowInset),
            self.chip.centerYAnchor.constraint(equalTo: self.titleLabel.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(chip text: String, colour: UIColor) {
        self.chip.show(text, colour: colour)
        self.accessibilityLabel = text.isEmpty ? self.titleLabel.text : "\(self.titleLabel.text ?? ""), \(text)"
    }
}

/// the one big button a step screen has.
final class FMXPrimaryButton: UIButton {
    private let gradient = FMXGradientView(colors: [FMXTheme.volt, FMXTheme.teal])

    init(title: String) {
        super.init(frame: .zero)

        self.gradient.layer.cornerRadius = 18
        self.gradient.layer.masksToBounds = true
        self.insertSubview(self.gradient, at: 0)

        self.setTitle(title, for: .normal)
        self.setTitleColor(FMXTheme.onInk, for: .normal)
        self.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)

        self.layer.shadowColor = FMXTheme.volt.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 10)
        self.layer.shadowRadius = 18
        self.layer.shadowOpacity = 0.32
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.gradient.frame = self.bounds
        self.layer.shadowPath = UIBezierPath(roundedRect: self.bounds, cornerRadius: 18).cgPath
    }

    override var isHighlighted: Bool {
        didSet { self.alpha = self.isHighlighted ? 0.82 : 1.0 }
    }

    override var isEnabled: Bool {
        didSet { self.alpha = self.isEnabled ? 1.0 : 0.45 }
    }
}
