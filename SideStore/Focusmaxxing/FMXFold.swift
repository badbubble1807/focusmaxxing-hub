//
//  FMXFold.swift
//  Focusmaxxing Hub
//
//  the pieces the switches screen is built from, so it looks like the extension's site blocker: a
//  card for each section (Block NSFW / Commonly blocked / Custom blocks), and inside Commonly
//  blocked a box per app that opens on an arrow to show its switches, with a glowing ACTIVE marker
//  on any box that has something blocked. this is the extension's `.card.panel > .pane > .fold`
//  written in UIKit, the same shapes and the same words (theme.css, popup.html, sites.js).
//
//  two things worth not re-learning:
//  - the rows are UIControls. a control nested inside a control is hit-tested first, so tapping a
//    switch fires the switch and tapping the rest of the row fires the row. every decoration on a
//    row (a label, the state switch drawn as a picture, a chevron) has its interaction turned off so
//    its touch falls through to the row; only a real second control (the trash on a custom app)
//    keeps its own touch. never put those decorations in a UIStackView on the row - a stack is
//    interaction-enabled and would swallow the touch before the row control saw it.
//  - a box or a section folds away by hiding a view that is an ARRANGED SUBVIEW of an outer stack.
//    hiding a view that is only pinned by constraints leaves its height behind - the box would look
//    open with blank space in it. so the fold and the pane are each an outer vertical stack, and
//    folding is isHidden on the part inside it.
//

import UIKit

// MARK: - the ACTIVE marker

/// a glowing volt dot and the word ACTIVE, shown on a fold that has something blocked. the
/// extension's `.fold-live` (a 7px dot with a 9px glow, then "Active" in accent-text).
final class FMXActiveMarker: UIView {
    private let dot = UIView()
    private let label = UILabel()

    init() {
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false

        self.dot.backgroundColor = FMXTheme.volt
        self.dot.layer.cornerRadius = 3.5
        self.dot.layer.shadowColor = FMXTheme.volt.cgColor
        self.dot.layer.shadowOffset = .zero
        self.dot.layer.shadowRadius = 4.5    // a css 9px blur is about twice core animation's radius
        self.dot.layer.shadowOpacity = 0.9

        self.label.attributedText = NSAttributedString(string: "ACTIVE", attributes: [
            .font: FMXFont.of(10, .heavy),
            .foregroundColor: FMXTheme.accentText,
            .kern: 1.0,
        ])

        for view in [self.dot, self.label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
        }
        NSLayoutConstraint.activate([
            self.dot.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.dot.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.dot.widthAnchor.constraint(equalToConstant: 7),
            self.dot.heightAnchor.constraint(equalToConstant: 7),

            self.label.leadingAnchor.constraint(equalTo: self.dot.trailingAnchor, constant: 6),
            self.label.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.label.topAnchor.constraint(equalTo: self.topAnchor),
            self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

// MARK: - a switch row (Instagram / YouTube per-part switches)

/// one real switch inside a fold: a name on the left, the wait switch on the right. it drives the
/// same FMXSwitchView and the same phases as the old switches screen; the view controller owns the
/// wait and tells the row which phase to show.
final class FMXSwitchRow: UIControl {
    let key: String
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let pill = FMXSwitchView()

    /// called for a tap on the row or on the switch - the two are one action, as on the old screen
    var onTap: (() -> Void)?

    init(key: String, title: String) {
        self.key = key
        super.init(frame: .zero)

        self.titleLabel.font = FMXFont.of(16, .semibold)
        self.titleLabel.textColor = FMXTheme.text
        self.titleLabel.numberOfLines = 0
        self.titleLabel.text = title

        self.statusLabel.font = FMXFont.of(12, .bold)
        self.statusLabel.textColor = FMXTheme.ember
        self.statusLabel.textAlignment = .right
        self.statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.pill.addTarget(self, action: #selector(fire), for: .touchUpInside)
        self.addTarget(self, action: #selector(fire), for: .touchUpInside)

        for view in [self.titleLabel, self.statusLabel, self.pill] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
        }

        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            self.pill.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.pill.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.pill.widthAnchor.constraint(equalToConstant: FMXSwitchView.width),
            self.pill.heightAnchor.constraint(equalToConstant: FMXSwitchView.height),

            self.statusLabel.trailingAnchor.constraint(equalTo: self.pill.leadingAnchor, constant: -10),
            self.statusLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 110),

            self.titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),
            self.titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 12),
            self.titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { self.onTap?() }

    func show(_ phase: FMXPhase) {
        self.pill.show(phase)
        switch phase {
        case .armed: self.statusLabel.text = "Tap to unblock"
        case .off, .on, .counting: self.statusLabel.text = ""
        }
    }
}

// MARK: - a guided row (Full block, a custom app, or Block NSFW)

/// a row that opens a guided screen rather than flipping a switch: the "Full block" row inside a
/// fold, a custom app's row, and the Block NSFW row. the switch on it is a picture of the state, not
/// a toggle - tapping anywhere but the trash opens the screen where the block is set up, exactly as
/// the NSFW row on the old screen did.
final class FMXGuidedRow: UIControl {
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let pill = FMXSwitchView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let removeButton = UIButton(type: .system)

    var onTap: (() -> Void)?
    var onRemove: (() -> Void)?

    /// heading:true renders the title like a section heading (Block NSFW is its rectangle's own
    /// heading, the way the extension styles that switch's label as a section-title).
    /// removable:true shows a trash button (a control of its own) for a custom app.
    init(title: String, heading: Bool = false, removable: Bool = false) {
        super.init(frame: .zero)

        if heading {
            self.titleLabel.attributedText = FMXPaneCard.heading(title)
        } else {
            self.titleLabel.font = FMXFont.of(16, .semibold)
            self.titleLabel.textColor = FMXTheme.text
            self.titleLabel.text = title
        }
        self.titleLabel.numberOfLines = 0

        self.statusLabel.font = FMXFont.of(12, .bold)
        self.statusLabel.textColor = FMXTheme.faint
        self.statusLabel.textAlignment = .right
        self.statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // the switch is a picture of the state, not a control: its touch falls through to the row
        self.pill.isUserInteractionEnabled = false

        self.chevron.tintColor = FMXTheme.faint
        self.chevron.contentMode = .scaleAspectFit
        self.chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        self.chevron.setContentHuggingPriority(.required, for: .horizontal)

        self.removeButton.setImage(UIImage(systemName: "trash"), for: .normal)
        self.removeButton.tintColor = FMXTheme.faint
        self.removeButton.isHidden = !removable
        self.removeButton.addTarget(self, action: #selector(removeTapped), for: .touchUpInside)

        self.addTarget(self, action: #selector(fire), for: .touchUpInside)

        for view in [self.titleLabel, self.statusLabel, self.pill, self.chevron, self.removeButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.addSubview(view)
        }

        // right-anchored chain: title (flex) -> status -> pill -> chevron -> [trash] -> edge
        NSLayoutConstraint.activate([
            self.heightAnchor.constraint(greaterThanOrEqualToConstant: 50),

            self.removeButton.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.removeButton.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.removeButton.widthAnchor.constraint(equalToConstant: removable ? 28 : 0),

            self.chevron.trailingAnchor.constraint(equalTo: self.removeButton.leadingAnchor, constant: removable ? -12 : 0),
            self.chevron.centerYAnchor.constraint(equalTo: self.centerYAnchor),

            self.pill.trailingAnchor.constraint(equalTo: self.chevron.leadingAnchor, constant: -10),
            self.pill.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.pill.widthAnchor.constraint(equalToConstant: FMXSwitchView.width),
            self.pill.heightAnchor.constraint(equalToConstant: FMXSwitchView.height),

            self.statusLabel.trailingAnchor.constraint(equalTo: self.pill.leadingAnchor, constant: -10),
            self.statusLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor),
            self.statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 110),

            self.titleLabel.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),
            self.titleLabel.topAnchor.constraint(equalTo: self.topAnchor, constant: 12),
            self.titleLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { self.onTap?() }
    @objc private func removeTapped() { self.onRemove?() }

    /// setUp:false shows the grey "not set up yet" switch and a note; when it is set up the switch
    /// shows on (or off, only for Block NSFW, whose block can be allowed while still set up).
    func show(setUp: Bool, on: Bool) {
        if !setUp {
            self.pill.showNotSetUp()
            self.statusLabel.text = "Not set up"
        } else {
            self.pill.show(on ? .on : .off)
            self.statusLabel.text = ""
        }
    }
}

// MARK: - a fold (one app in Commonly blocked)

/// an app's box: a name and an arrow, its rows folded away underneath until it is opened. the arrow
/// turns, the ACTIVE marker shows when anything inside is on, and the box gets a firmer edge and a
/// faint glow while it is open - the extension's `.fold`. it is an outer vertical stack of a header,
/// a hairline and a body, so folding is isHidden on the body (and the hairline) and the box really
/// shrinks.
final class FMXFoldView: UIView {
    private let outer = UIStackView()
    private let header = UIControl()
    private let nameLabel = UILabel()
    private let marker = FMXActiveMarker()
    private let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let divider = UIView()
    private let body = UIStackView()

    private static let openGlow = UIColor(red: 233 / 255, green: 1, blue: 246 / 255, alpha: 1)

    private(set) var isOpen = false

    init(name: String) {
        super.init(frame: .zero)

        self.backgroundColor = FMXTheme.cardLifted
        self.layer.cornerRadius = FMXTheme.radiusSmall
        self.layer.cornerCurve = .continuous
        self.layer.borderWidth = 1
        self.layer.borderColor = FMXTheme.hairline.cgColor

        self.nameLabel.font = FMXFont.of(15, .bold)
        self.nameLabel.textColor = FMXTheme.text
        self.nameLabel.text = name

        self.marker.isHidden = true

        self.arrow.tintColor = FMXTheme.faint
        self.arrow.contentMode = .scaleAspectFit
        self.arrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)

        self.header.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        let headRow = UIStackView(arrangedSubviews: [self.nameLabel, self.marker, self.arrow])
        headRow.axis = .horizontal
        headRow.alignment = .center
        headRow.spacing = 10
        headRow.isUserInteractionEnabled = false      // taps fall through to the header control
        headRow.translatesAutoresizingMaskIntoConstraints = false
        self.header.addSubview(headRow)
        NSLayoutConstraint.activate([
            headRow.leadingAnchor.constraint(equalTo: self.header.leadingAnchor, constant: 12),
            headRow.trailingAnchor.constraint(equalTo: self.header.trailingAnchor, constant: -12),
            headRow.topAnchor.constraint(equalTo: self.header.topAnchor, constant: 12),
            headRow.bottomAnchor.constraint(equalTo: self.header.bottomAnchor, constant: -12),
        ])

        // the hairline under the name once the box is open (full width, like the extension's
        // fold-head border-bottom), hidden while shut
        self.divider.backgroundColor = FMXTheme.hairline
        self.divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        self.divider.isHidden = true

        self.body.axis = .vertical
        self.body.spacing = 0
        self.body.isLayoutMarginsRelativeArrangement = true
        self.body.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 8, trailing: 12)
        self.body.isHidden = true

        self.outer.axis = .vertical
        self.outer.spacing = 0
        self.outer.addArrangedSubview(self.header)
        self.outer.addArrangedSubview(self.divider)
        self.outer.addArrangedSubview(self.body)
        self.outer.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.outer)
        NSLayoutConstraint.activate([
            self.outer.topAnchor.constraint(equalTo: self.topAnchor),
            self.outer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.outer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.outer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// add a row to the fold's body, with a hairline above it if it is not the first
    func addRow(_ row: UIView) {
        if !self.body.arrangedSubviews.isEmpty {
            let line = UIView()
            line.backgroundColor = FMXTheme.hairline
            line.heightAnchor.constraint(equalToConstant: 1).isActive = true
            self.body.addArrangedSubview(line)
        }
        self.body.addArrangedSubview(row)
    }

    /// the glowing ACTIVE marker, shown when anything inside the box is on
    func setLive(_ live: Bool) {
        self.marker.isHidden = !live
    }

    @objc private func toggle() {
        self.setOpen(!self.isOpen, animated: FMXTheme.animationsWanted)
    }

    func setOpen(_ open: Bool, animated: Bool) {
        self.isOpen = open

        let apply = {
            self.body.isHidden = !open
            self.divider.isHidden = !open
            self.arrow.transform = open ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
            self.layer.borderColor = (open ? FMXTheme.hairlineStrong : FMXTheme.hairline).cgColor
            // open, the box reads as the one being worked in: a firmer edge and a glow so faint it
            // is nearly white - the accent is saved for what is actually blocked (the extension's
            // rule). the glow's path is set again in layoutSubviews once the new size is known.
            if open { self.applyOpenGlow() } else { self.layer.shadowOpacity = 0 }
            self.fmxLayoutEnclosingScroll()
        }

        guard animated else { apply(); return }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: apply)
    }

    private func applyOpenGlow() {
        FMXTheme.glow(on: self.layer, bounds: self.bounds, radius: FMXTheme.radiusSmall,
                      colour: FMXFoldView.openGlow, y: 10, blur: 30, spread: 20, opacity: 0.16)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if self.isOpen { self.applyOpenGlow() }
    }
}

// MARK: - a pane card (one of the three rectangles)

/// one of the three rounded rectangles: a heading, an optional arrow to fold the whole thing away,
/// and a column of content under it. the extension's `.card.panel > .pane`. Block NSFW passes no
/// title (its single row is its own heading); Commonly blocked and Custom blocks pass a title and
/// are collapsible. an outer vertical stack again, so folding really shrinks the card.
final class FMXPaneCard: UIView {
    private let outer = UIStackView()
    private let header = UIControl()
    private let titleLabel = UILabel()
    private let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let content = UIStackView()

    private var isOpen = true
    private let collapsible: Bool

    /// the small uppercase heading the extension calls a section-title, used both here and for the
    /// Block NSFW row's own label.
    static func heading(_ text: String) -> NSAttributedString {
        return NSAttributedString(string: text.uppercased(), attributes: [
            .font: FMXFont.of(12, .heavy),
            .foregroundColor: FMXTheme.muted,
            .kern: 1.1,
        ])
    }

    init(title: String?, collapsible: Bool = false, contentSpacing: CGFloat = 8) {
        self.collapsible = collapsible && title != nil
        super.init(frame: .zero)

        self.backgroundColor = FMXTheme.card
        self.layer.cornerRadius = FMXTheme.radius
        self.layer.cornerCurve = .continuous
        self.layer.borderWidth = 1
        self.layer.borderColor = FMXTheme.hairline.cgColor

        self.content.axis = .vertical
        self.content.spacing = contentSpacing
        self.content.isLayoutMarginsRelativeArrangement = true

        self.outer.axis = .vertical
        self.outer.spacing = 0
        self.outer.translatesAutoresizingMaskIntoConstraints = false

        if let title = title {
            self.titleLabel.attributedText = FMXPaneCard.heading(title)

            self.arrow.tintColor = FMXTheme.faint
            self.arrow.contentMode = .scaleAspectFit
            self.arrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            self.arrow.isHidden = !self.collapsible
            self.arrow.transform = CGAffineTransform(rotationAngle: .pi / 2)     // open points down

            let headRow = UIStackView(arrangedSubviews: [self.titleLabel, self.arrow])
            headRow.axis = .horizontal
            headRow.alignment = .center
            headRow.isUserInteractionEnabled = false
            headRow.translatesAutoresizingMaskIntoConstraints = false
            self.header.addSubview(headRow)
            self.header.isUserInteractionEnabled = self.collapsible
            if self.collapsible { self.header.addTarget(self, action: #selector(toggle), for: .touchUpInside) }
            NSLayoutConstraint.activate([
                headRow.topAnchor.constraint(equalTo: self.header.topAnchor, constant: 14),
                headRow.bottomAnchor.constraint(equalTo: self.header.bottomAnchor, constant: -10),
                headRow.leadingAnchor.constraint(equalTo: self.header.leadingAnchor, constant: 16),
                headRow.trailingAnchor.constraint(equalTo: self.header.trailingAnchor, constant: -16),
            ])
            self.outer.addArrangedSubview(self.header)
            self.content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 12, trailing: 12)
        } else {
            // no heading (Block NSFW): the single row's own label is the heading, so line its edge up
            // with the other panes' headings (16), and give the card its top and bottom air
            self.content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        }

        self.outer.addArrangedSubview(self.content)
        self.addSubview(self.outer)
        NSLayoutConstraint.activate([
            self.outer.topAnchor.constraint(equalTo: self.topAnchor),
            self.outer.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.outer.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            self.outer.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// add a row/fold/view to the card's column
    func addContent(_ view: UIView) {
        self.content.addArrangedSubview(view)
    }

    /// a full-width hairline between two rows (the Custom blocks list)
    func addSeparator() {
        let line = UIView()
        line.backgroundColor = FMXTheme.hairline
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        self.content.addArrangedSubview(line)
    }

    /// take everything out of the column, so the Custom blocks list can be rebuilt after an add or
    /// a remove
    func clearContent() {
        for view in self.content.arrangedSubviews {
            self.content.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }

    @objc private func toggle() {
        self.isOpen.toggle()
        let apply = {
            self.content.isHidden = !self.isOpen
            self.arrow.transform = self.isOpen ? CGAffineTransform(rotationAngle: .pi / 2) : .identity
            self.fmxLayoutEnclosingScroll()
        }
        guard FMXTheme.animationsWanted else { apply(); return }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut, .beginFromCurrentState], animations: apply)
    }
}

// MARK: - laying out the column around a fold

// a fold or a pane opening should move the cards around it in step, not snap them into place at the
// end of the animation. the height change has to reach the scrolling column above it, so the layout
// is flushed on the nearest scroll view rather than on the folding view alone.
private extension UIView {
    func fmxLayoutEnclosingScroll() {
        var view: UIView? = self
        while let current = view, !(current is UIScrollView) { view = current.superview }
        (view ?? self).layoutIfNeeded()
    }
}
