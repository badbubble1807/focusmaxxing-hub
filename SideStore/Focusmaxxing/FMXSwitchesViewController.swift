//
//  FMXSwitchesViewController.swift
//  Focusmaxxing Hub
//
//  the phone's own screen, built to look like the extension's site blocker (2026-09-08, the owner:
//  "just copy THE EXACT SAME THING from the site blocker on my extension onto my mobile app but
//  instead of blocking sites, it blocks my apps"). three rounded rectangles down one column:
//
//    Block NSFW        - one row, its label is its heading, opens FMXAdultViewController
//    Commonly blocked  - eight app boxes in the extension's order, each opening on an arrow to its
//                        switches, with the glowing ACTIVE marker on any box that has something on.
//                        Instagram and YouTube open onto their per-part switches (the real ones we
//                        tweak) with a Full block above them; the other six open onto their one Full
//                        block row.
//    Custom blocks     - any app the owner names, each a Full block of its own, removable
//
//  and under them the Unblocking-countdown card (the wait slider), unchanged.
//
//  a per-part switch is a real block, enforced inside Instagram or YouTube: instant on, the wait to
//  turn off, the 24-hour lock on the wait, the countdown thrown away on leaving - none of that
//  changed, it just lives on FMXSwitchRow now instead of a table cell. a "Full block" (and every
//  custom app) is a guided Screen Time block with a tick of its own (FMXFullBlock), never a switch,
//  so it can never claim a block the phone is not keeping. see FMXFold.swift for the pieces.
//

import UIKit

final class FMXSwitchesViewController: UIViewController {
    private let store = FMXSwitchStore.shared

    // the countdown, per switch key, deliberately not persisted: leaving the screen or the app
    // throws it away, so a wait can never be sat through in the background
    private var readyAt = [String: Date]()
    private var ticker: Timer?

    private let scrollView = UIScrollView()
    private let column = UIStackView()

    // what the tick repaints, held so a countdown can be redrawn without rebuilding anything
    private var switchRows = [String: FMXSwitchRow]()
    private var fullBlockRows = [(row: FMXGuidedRow, id: String)]()
    private var customRows = [(row: FMXGuidedRow, id: String)]()
    private var folds = [(fold: FMXFoldView, app: FMXFullBlockApp)]()
    private var nsfwRow: FMXGuidedRow!

    private var customPane: FMXPaneCard!
    private var waitCard: FMXWaitCard!

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = "Focusmaxxing mobile"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()

        // a phone set up under the older two-tick NSFW version keeps its ticks
        FMXAdultBlock.migrateOldTicks()

        self.navigationItem.largeTitleDisplayMode = .always
        self.navigationController?.navigationBar.prefersLargeTitles = true
        FMXTheme.style(navigationItem: self.navigationItem)

        self.view.backgroundColor = FMXTheme.ink
        let backdrop = FMXTheme.backdrop()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(backdrop)

        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.backgroundColor = .clear
        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)

        self.column.axis = .vertical
        self.column.spacing = 14
        self.column.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.addSubview(self.column)

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: self.view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),

            self.column.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor, constant: 14),
            self.column.bottomAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            self.column.leadingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            self.column.trailingAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
        ])

        // make sure the shared file exists even before anything has been touched
        self.store.export()

        self.buildColumn()

        NotificationCenter.default.addObserver(self, selector: #selector(resetWaits), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ticks may have changed on a guided screen we came back from; the countdowns start clean
        self.readyAt.removeAll()
        self.refresh()
        // .common mode, not the default: a default-mode timer stops firing while the screen is
        // being scrolled under a finger, so a running countdown would freeze and then jump when the
        // finger lifted. the wait itself is wall-clock (readyAt), so only the drawing was ever at risk.
        let ticker = Timer(timeInterval: 0.25, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.ticker?.invalidate()
        self.ticker = nil
        self.resetWaits()
    }

    // closing the screen, or leaving the app, throws every countdown away
    @objc private func resetWaits() {
        self.readyAt.removeAll()
        self.refresh()
    }

    // MARK: building the three rectangles

    private func buildColumn() {
        self.column.addArrangedSubview(self.makeNSFWPane())
        self.column.addArrangedSubview(self.makeCommonPane())

        self.customPane = FMXPaneCard(title: "Custom blocks", collapsible: true, contentSpacing: 0)
        self.column.addArrangedSubview(self.customPane)
        self.populateCustom()

        self.waitCard = FMXWaitCard()
        self.waitCard.onCommit = { [weak self] seconds in
            guard let self else { return false }
            let ok = self.store.setWaitSeconds(seconds)
            DispatchQueue.main.async { self.refresh() }
            return ok
        }
        self.column.addArrangedSubview(self.waitCard)
    }

    private func makeNSFWPane() -> FMXPaneCard {
        // no separate heading: the row's own label "Block NSFW" is the rectangle's heading, the way
        // the extension styles that switch's label as a section-title
        let pane = FMXPaneCard(title: nil)
        let row = FMXGuidedRow(title: "Block NSFW", heading: true)
        row.onTap = { [weak self] in self?.openAdult() }
        self.nsfwRow = row
        pane.addContent(row)
        return pane
    }

    private func makeCommonPane() -> FMXPaneCard {
        let pane = FMXPaneCard(title: "Commonly blocked", collapsible: true, contentSpacing: 8)

        for app in FMXFullBlock.builtIn {
            let fold = FMXFoldView(name: app.name)

            // the Full block row, first, for every app - Instagram and YouTube included
            let fullBlock = FMXGuidedRow(title: "Full block")
            fullBlock.onTap = { [weak self] in self?.openFullBlock(app) }
            fold.addRow(fullBlock)
            self.fullBlockRows.append((fullBlock, app.id))

            // the two apps we tweak also carry their real per-part switches
            if let fmxApp = FMXFullBlock.switchApp(for: app.id) {
                for sw in self.store.switches(for: fmxApp) {
                    let row = FMXSwitchRow(key: sw.key, title: sw.label)
                    row.onTap = { [weak self] in self?.tapped(sw) }
                    fold.addRow(row)
                    self.switchRows[sw.key] = row
                }
            }

            self.folds.append((fold, app))
            pane.addContent(fold)
        }
        return pane
    }

    // built once, and again whenever a custom app is added or removed
    private func populateCustom() {
        self.customPane.clearContent()
        self.customRows.removeAll()

        let apps = FMXFullBlock.customApps()
        if apps.isEmpty {
            let empty = UILabel()
            empty.font = FMXFont.of(13, .regular)
            empty.textColor = FMXTheme.faint
            empty.numberOfLines = 0
            empty.text = "Nothing added yet. Block any other app the same way."
            self.customPane.addContent(empty)
        }

        for (index, app) in apps.enumerated() {
            if index > 0 { self.customPane.addSeparator() }
            let row = FMXGuidedRow(title: app.name, removable: true)
            row.onTap = { [weak self] in self?.openFullBlock(app) }
            row.onRemove = { [weak self] in self?.promptRemove(app) }
            self.customPane.addContent(row)
            self.customRows.append((row, app.id))
        }

        if !apps.isEmpty { self.customPane.addSeparator() }
        self.customPane.addContent(self.makeAddButton())

        self.refresh()
    }

    private func makeAddButton() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("+  Add an app", for: .normal)
        button.setTitleColor(FMXTheme.accentText, for: .normal)
        button.titleLabel?.font = FMXFont.of(15, .bold)
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: #selector(addAppTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
        return button
    }

    // MARK: the switches (per-part, real blocks)

    private func phase(for key: String) -> FMXPhase {
        if !self.store.isBlocked(key) { return .off }
        guard let ready = self.readyAt[key] else { return .on }
        let remaining = ready.timeIntervalSinceNow
        if remaining > 0 { return .counting(Int(remaining.rounded(.up))) }
        return .armed
    }

    private func tapped(_ sw: FMXSwitch) {
        switch self.phase(for: sw.key) {
        case .off:
            self.store.setBlocked(true, key: sw.key)
        case .on:
            self.readyAt[sw.key] = Date(timeIntervalSinceNow: TimeInterval(self.store.waitSeconds))
        case .counting:
            break
        case .armed:
            self.readyAt.removeValue(forKey: sw.key)
            self.store.setBlocked(false, key: sw.key)
        }
        self.refresh()
    }

    @objc private func tick() { self.refresh() }

    // repaint every switch's phase, every guided row's state, every fold's ACTIVE marker, and the
    // wait card's lock line, from the store and the ticks. touches no open/shut fold state.
    private func refresh() {
        for (key, row) in self.switchRows { row.show(self.phase(for: key)) }

        // ?. rather than a force-unwrap: nsfwRow is set in makeNSFWPane before the first refresh
        // today, but that safety should not hang on statement order in buildColumn
        self.nsfwRow?.show(setUp: UserDefaults.standard.fmxAdultDone,
                           on: self.store.isBlocked(FMXAdultBlock.switchKey))

        for entry in self.fullBlockRows {
            let setUp = FMXFullBlock.isSetUp(entry.id)
            entry.row.show(setUp: setUp, on: setUp)
        }
        for entry in self.customRows {
            let setUp = FMXFullBlock.isSetUp(entry.id)
            entry.row.show(setUp: setUp, on: setUp)
        }
        for entry in self.folds {
            entry.fold.setLive(self.isLive(entry.app))
        }

        self.waitCard?.refreshLock(self.store.waitLockRemaining)
    }

    // a box glows ACTIVE when anything inside it is on: a per-part switch blocked (Instagram and
    // YouTube start fully blocked, the product's default), or its Full block set up.
    private func isLive(_ app: FMXFullBlockApp) -> Bool {
        if let fmxApp = FMXFullBlock.switchApp(for: app.id) {
            let anyBlocked = self.store.switches(for: fmxApp).contains { self.store.isBlocked($0.key) }
            return anyBlocked || FMXFullBlock.isSetUp(app.id)
        }
        return FMXFullBlock.isSetUp(app.id)
    }

    // MARK: opening the guided screens

    private func openAdult() {
        guard let navigationController = self.navigationController, navigationController.topViewController === self else { return }
        navigationController.pushViewController(FMXAdultViewController(), animated: true)
    }

    private func openFullBlock(_ app: FMXFullBlockApp) {
        guard let navigationController = self.navigationController, navigationController.topViewController === self else { return }
        navigationController.pushViewController(FMXFullBlockViewController(app: app), animated: true)
    }

    // MARK: custom apps

    @objc private func addAppTapped() {
        let alert = UIAlertController(title: "Block another app",
                                      message: "Type the app's name as it shows on your phone. You'll set it up in Screen Time next.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "App name"
            field.autocapitalizationType = .words
            field.autocorrectionType = .no
            field.returnKeyType = .done
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self, let name = alert?.textFields?.first?.text else { return }
            guard FMXFullBlock.addCustomApp(named: name) != nil else { return }
            // the new row appears saying "Not set up"; tapping it opens the guided steps. we do not
            // push that screen from here, so there is never a push racing the alert's own dismissal.
            self.populateCustom()
        })
        self.present(alert, animated: true)
    }

    private func promptRemove(_ app: FMXFullBlockApp) {
        let alert = UIAlertController(title: "Remove \(app.name)?",
                                      message: "This only takes it off the list. It does not unblock it in Screen Time — do that in Settings.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { [weak self] _ in
            FMXFullBlock.removeCustomApp(id: app.id)
            self?.populateCustom()
        })
        self.present(alert, animated: true)
    }
}

// MARK: - the Unblocking-countdown card (the wait slider)

/// the fourth rectangle: the wait every switch makes you sit through before it lets go, on a slider,
/// with the 24-hour lock. a straight port of the old screen's wait row into a card of its own, so
/// nothing about the wait or the lock changed - only where it is drawn. the extension's
/// "Unblocking countdown" card.
private final class FMXWaitCard: UIView {
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private let scale = UILabel()
    private let note = UILabel()
    private let lock = UILabel()

    /// returns false when the slider is locked for the day, so the card can snap back
    var onCommit: ((Int) -> Bool)?

    init() {
        super.init(frame: .zero)

        self.backgroundColor = FMXTheme.card
        self.layer.cornerRadius = FMXTheme.radius
        self.layer.cornerCurve = .continuous
        self.layer.borderWidth = 1
        self.layer.borderColor = FMXTheme.hairline.cgColor

        let heading = UILabel()
        heading.attributedText = FMXPaneCard.heading("Unblocking countdown")

        self.valueLabel.font = FMXFont.counting(20, .heavy)
        self.valueLabel.textColor = FMXTheme.accentText
        self.valueLabel.textAlignment = .right
        self.valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.note.font = FMXFont.of(12.5, .regular)
        self.note.textColor = FMXTheme.faint
        self.note.numberOfLines = 0
        self.note.text = "How long a switch makes you wait before it lets go. Blocking something is always instant."

        self.scale.font = FMXFont.of(11, .medium)
        self.scale.textColor = FMXTheme.faint
        self.scale.text = "\(FMXSwitchStore.minWait)s to \(FMXSwitchStore.maxWait)s"
        self.scale.textAlignment = .right

        self.lock.font = FMXFont.of(12.5, .regular)
        self.lock.textColor = FMXTheme.faint
        self.lock.numberOfLines = 0

        self.slider.minimumValue = Float(FMXSwitchStore.minWait)
        self.slider.maximumValue = Float(FMXSwitchStore.maxWait)
        self.slider.isContinuous = true
        self.slider.maximumTrackTintColor = FMXTheme.surfaceHigh
        self.slider.thumbTintColor = .white
        self.slider.addTarget(self, action: #selector(moved), for: .valueChanged)
        self.slider.addTarget(self, action: #selector(released), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        // start on what the store holds now
        let seconds = FMXSwitchStore.shared.waitSeconds
        self.slider.value = Float(seconds)
        self.show(seconds: seconds)

        let topRow = UIStackView(arrangedSubviews: [heading, self.valueLabel])
        topRow.axis = .horizontal
        topRow.alignment = .firstBaseline

        let stack = UIStackView(arrangedSubviews: [topRow, self.note, self.slider, self.scale, self.lock])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(10, after: self.note)
        stack.setCustomSpacing(2, after: self.slider)
        stack.setCustomSpacing(10, after: self.scale)
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16),
        ])

        self.refreshLock(FMXSwitchStore.shared.waitLockRemaining)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func show(seconds: Int) {
        self.valueLabel.text = "\(seconds)s"
    }

    // the lock line counts down, and the slider greys out while it is locked. the value and the
    // slider position are set only by the customer's drag, so a tick never fights a finger.
    func refreshLock(_ remaining: TimeInterval) {
        let locked = remaining > 0
        self.slider.isEnabled = !locked
        self.slider.minimumTrackTintColor = locked ? FMXTheme.slate : FMXTheme.teal
        self.valueLabel.textColor = locked ? FMXTheme.faint : FMXTheme.accentText

        if locked {
            self.lock.text = "Locked for another \(FMXSwitchStore.shared.formatDuration(remaining)) — changing this is a decision too, so it only moves once a day."
        } else {
            self.lock.text = "You can change this now. Once you do, it locks for a day."
        }
    }

    @objc private func moved() {
        self.show(seconds: Int(self.slider.value.rounded()))
    }

    @objc private func released() {
        let seconds = Int(self.slider.value.rounded())
        self.slider.value = Float(seconds)
        if let onCommit = self.onCommit, !onCommit(seconds) {
            // locked: snap back to what it was
            let current = FMXSwitchStore.shared.waitSeconds
            self.slider.value = Float(current)
            self.show(seconds: current)
        }
    }
}
