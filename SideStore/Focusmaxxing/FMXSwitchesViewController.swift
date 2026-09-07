//
//  FMXSwitchesViewController.swift
//  Focusmaxxing Hub
//
//  the switches screen. one row per switch, with the switch itself on the right: the volt
//  gradient with the knob over is blocked, a plain grey track with the knob back is allowed. no
//  on or off is written anywhere - the colour is the state, the same as the desktop popup. the
//  control itself is FMXSwitchView in FMXControls.swift, drawn from the same numbers as the one
//  on the other two screens of this product.
//
//  turning a block on is instant. turning one off costs the wait: the first tap turns the switch
//  ember and counts the seconds down inside it, taps during the countdown are ignored, and at zero
//  the row says "Tap to unblock" - a second tap unblocks. leaving this screen, or leaving the app,
//  throws every countdown away.
//
//  each heading carries how much of that app is blocked, which is the badge the desktop app puts
//  on a site with something blocked. at the bottom: the wait itself, 10 to 30 seconds, locked for
//  24 hours after every change. a change lands the next time the app is opened; the footer says so.
//
//  the first section is the adult-websites row. it is not an app switch: the block itself lives in
//  the phone's own settings, so the row only shows the state and opens FMXAdultViewController,
//  which holds the switch, the wait and the steps.
//

import UIKit

final class FMXSwitchesViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case adult
        case instagram
        case youtube
        case wait
    }

    private let store = FMXSwitchStore.shared
    private var readyAt = [String: Date]()   // deliberately not persisted
    private var ticker: Timer?

    // the headings, kept so the badge on one can be redrawn without reloading the list under a
    // finger that is in the middle of a countdown
    private var headers = [Int: FMXSectionHeader]()

    init() {
        super.init(style: .insetGrouped)
        self.title = "Switches"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()

        // a phone set up under the older two-tick version keeps its ticks
        FMXAdultBlock.migrateOldTicks()

        self.navigationItem.largeTitleDisplayMode = .always
        self.navigationController?.navigationBar.prefersLargeTitles = true
        FMXTheme.style(navigationItem: self.navigationItem)
        FMXTheme.style(tableView: self.tableView)

        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 64

        // make sure the shared file exists even before anything has been touched
        self.store.export()

        NotificationCenter.default.addObserver(self, selector: #selector(resetWaits), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        self.ticker = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
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
        self.refreshVisible()
    }

    // MARK: phases

    private func switches(in section: Section) -> [FMXSwitch] {
        switch section {
        case .instagram: return self.store.switches(for: .instagram)
        case .youtube: return self.store.switches(for: .youtube)
        case .adult, .wait: return []
        }
    }

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
        self.refreshVisible()
    }

    @objc private func tick() { self.refreshVisible() }

    private func refreshVisible() {
        for indexPath in self.tableView.indexPathsForVisibleRows ?? [] {
            // the adult row has no countdown of its own (its screen holds it), so it is left alone
            guard let section = Section(rawValue: indexPath.section), section != .wait, section != .adult,
                  let cell = self.tableView.cellForRow(at: indexPath) as? FMXSwitchCell else { continue }
            let sw = self.switches(in: section)[indexPath.row]
            cell.show(self.phase(for: sw.key))
        }
        self.refreshHeaders()
        // the lock footer counts down too
        if let footer = self.tableView.footerView(forSection: Section.wait.rawValue) {
            self.style(footer: footer, section: Section.wait.rawValue)
        }
    }

    // the small print under a group. it is written through the row's own configuration rather
    // than by reaching for its label, which is the part iOS keeps taking back.
    private func style(footer: UITableViewHeaderFooterView, section: Int) {
        var configuration = footer.defaultContentConfiguration()
        configuration.text = self.tableView(self.tableView, titleForFooterInSection: section)
        configuration.textProperties.font = .systemFont(ofSize: 12.5, weight: .regular)
        configuration.textProperties.color = FMXTheme.faint
        configuration.textProperties.numberOfLines = 0
        footer.contentConfiguration = configuration
    }

    // MARK: the badges

    private func refreshHeaders() {
        for (section, header) in self.headers {
            guard let section = Section(rawValue: section) else { continue }
            switch section {
            case .instagram, .youtube:
                let all = self.switches(in: section)
                let blocked = all.filter { self.store.isBlocked($0.key) }.count
                if blocked == all.count {
                    header.show(chip: "All blocked", colour: FMXTheme.volt)
                } else if blocked == 0 {
                    header.show(chip: "Nothing blocked", colour: FMXTheme.slate)
                } else {
                    header.show(chip: "\(blocked) of \(all.count) blocked", colour: FMXTheme.teal)
                }

            case .wait:
                header.show(chip: self.store.waitLockRemaining > 0 ? "Locked" : "", colour: FMXTheme.ember)

            case .adult:
                break
            }
        }
    }

    private func waitFooter() -> String {
        let left = self.store.waitLockRemaining
        if left > 0 {
            return "The wait moves once a day. Locked for another \(self.store.formatDuration(left))."
        }
        return "How long an unblock makes you wait. The wait moves once a day: change it and the slider locks for 24 hours."
    }

    // MARK: table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .adult, .wait: return 1
        case .instagram, .youtube: return self.switches(in: section).count
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title: String
        switch Section(rawValue: section) {
        case .adult: title = "The whole phone"
        case .instagram: title = FMXApp.instagram.title
        case .youtube: title = FMXApp.youtube.title
        case .wait: title = "The wait"
        case nil: return nil
        }

        let header = FMXSectionHeader(title: title)
        self.headers[section] = header
        self.refreshHeaders()
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return FMXSectionHeader.height
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .adult:
            return "This one is not inside an app. Tap the row: Focusmaxxing Hub cannot block a website by itself, so it walks you through the two settings on the phone that can."
        case .instagram, .youtube:
            let app = section == Section.instagram.rawValue ? FMXApp.instagram : FMXApp.youtube
            return "Blocking is instant; unblocking makes you wait, and leaving this screen starts the wait over. Changes apply the next time \(app.title) is opened."
        case .wait:
            return self.waitFooter()
        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        self.style(footer: footer, section: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        if section == .adult {
            // the same row as a switch, but the switch only shows the state: tapping anywhere opens
            // the adult screen, where the switch, the countdown and the setup live together. the
            // arrow is there because the owner's own test found the row did not look tappable.
            let cell = FMXSwitchCell(style: .default, reuseIdentifier: nil)
            cell.titleLabel.text = "Adult websites"
            cell.accessoryType = .disclosureIndicator
            // this row goes somewhere, so it lights up under the finger. the switch rows keep
            // .none: a tap there flips a switch rather than opening anything.
            cell.selectionStyle = .default
            if UserDefaults.standard.fmxAdultDone {
                cell.subLabel.text = "Screen Time and a private DNS"
                cell.show(self.store.isBlocked(FMXAdultBlock.switchKey) ? .on : .off)
            } else {
                // grey until the setup has been walked through: green here would claim a block
                // that does not exist yet
                cell.subLabel.text = "Not set up yet. Tap to set it up."
                cell.showNotSetUp()
            }
            cell.onTap = { [weak self] in self?.openAdult() }
            return cell
        }

        if section == .wait {
            let cell = FMXWaitCell(style: .default, reuseIdentifier: nil)
            cell.slider.value = Float(self.store.waitSeconds)
            cell.setLocked(self.store.waitLockRemaining > 0)
            cell.show(seconds: self.store.waitSeconds)
            cell.onCommit = { [weak self] seconds in
                guard let self else { return false }
                let ok = self.store.setWaitSeconds(seconds)
                DispatchQueue.main.async {
                    self.tableView.reloadSections(IndexSet(integer: Section.wait.rawValue), with: .none)
                }
                return ok
            }
            return cell
        }

        let sw = self.switches(in: section)[indexPath.row]
        let cell = FMXSwitchCell(style: .default, reuseIdentifier: nil)
        cell.titleLabel.text = sw.label
        cell.subLabel.text = sw.sub
        cell.show(self.phase(for: sw.key))
        cell.onTap = { [weak self] in self?.tapped(sw) }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // a row that stays selected stays lit: the card is a shade lighter while a finger is on
        // it, and "selected" counts as a finger on it
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let section = Section(rawValue: indexPath.section), section != .wait else { return }
        if section == .adult {
            self.openAdult()
            return
        }
        self.tapped(self.switches(in: section)[indexPath.row])
    }

    private func openAdult() {
        // a second tap while the first screen is still sliding in would put two of them on the pile
        guard let navigationController = self.navigationController, navigationController.topViewController === self else { return }
        navigationController.pushViewController(FMXAdultViewController(), animated: true)
    }
}

// MARK: - the wait row

private final class FMXWaitCell: FMXCell {
    let label = UILabel()
    let valueLabel = UILabel()
    let slider = UISlider()
    var onCommit: ((Int) -> Bool)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.label.font = .systemFont(ofSize: 16, weight: .semibold)
        self.label.textColor = FMXTheme.text
        self.label.text = "Unblock wait"

        self.valueLabel.font = .monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        self.valueLabel.textColor = FMXTheme.accentText
        self.valueLabel.textAlignment = .right
        self.valueLabel.setContentHuggingPriority(.required, for: .horizontal)

        self.slider.minimumValue = Float(FMXSwitchStore.minWait)
        self.slider.maximumValue = Float(FMXSwitchStore.maxWait)
        self.slider.isContinuous = true
        self.slider.maximumTrackTintColor = FMXTheme.surfaceHigh
        self.slider.thumbTintColor = .white
        self.slider.addTarget(self, action: #selector(moved), for: .valueChanged)
        self.slider.addTarget(self, action: #selector(released), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        for view in [self.label, self.valueLabel, self.slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 13),

            self.valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: self.label.trailingAnchor, constant: 8),
            self.valueLabel.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.valueLabel.centerYAnchor.constraint(equalTo: self.label.centerYAnchor),

            self.slider.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.slider.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.slider.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 8),
            self.slider.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(seconds: Int) {
        self.valueLabel.text = "\(seconds) s"
    }

    // locked for the day: the slider still shows where it stands, in grey, and will not move
    func setLocked(_ locked: Bool) {
        self.slider.isEnabled = !locked
        self.slider.minimumTrackTintColor = locked ? FMXTheme.slate : FMXTheme.teal
        self.valueLabel.textColor = locked ? FMXTheme.faint : FMXTheme.accentText
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
