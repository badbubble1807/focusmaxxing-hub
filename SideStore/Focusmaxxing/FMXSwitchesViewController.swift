//
//  FMXSwitchesViewController.swift
//  Focusmaxxing Hub
//
//  the switches screen. one row per switch, with a coloured pill on the right: green is
//  blocked, red is allowed. there is no on/off text; the colour is the state, the same
//  as the desktop popup. a port of mobile/shared/FMXSettingsViewController.m.
//
//  turning a block on is instant. turning one off costs the wait: the first tap turns
//  the pill amber and counts down, taps during the countdown are ignored, and at zero
//  it says "Tap to unblock" - a second tap unblocks. leaving this screen, or leaving
//  the app, throws every countdown away.
//
//  at the bottom: the wait itself, 10 to 30 seconds, locked for 24 hours after every
//  change. a change lands the next time the app is opened; the footer says so.
//

import UIKit

private enum FMXPhase {
    case off             // allowed; a tap blocks, instantly
    case on              // blocked; a tap starts the wait
    case counting(Int)   // waiting; taps are ignored
    case armed           // the wait is up; a tap unblocks
}

private extension UIColor {
    static let fmxGreen = UIColor(red: 0.20, green: 0.78, blue: 0.45, alpha: 1.0)
    static let fmxRed   = UIColor(red: 0.93, green: 0.33, blue: 0.31, alpha: 1.0)
    static let fmxAmber = UIColor(red: 0.96, green: 0.68, blue: 0.20, alpha: 1.0)
}

// MARK: - the row

private final class FMXSwitchCell: UITableViewCell {
    let titleLabel = UILabel()
    let subLabel = UILabel()
    let statusLabel = UILabel()
    let pill = UIButton(type: .custom)
    var onTap: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        self.titleLabel.textColor = .label

        self.subLabel.font = .systemFont(ofSize: 12)
        self.subLabel.textColor = .secondaryLabel
        self.subLabel.numberOfLines = 2

        self.statusLabel.font = .systemFont(ofSize: 12)
        self.statusLabel.textColor = .fmxAmber
        self.statusLabel.textAlignment = .right
        self.statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.statusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.pill.layer.cornerRadius = 15
        self.pill.clipsToBounds = true
        self.pill.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        self.pill.setTitleColor(.white, for: .normal)
        self.pill.addTarget(self, action: #selector(pillTapped), for: .touchUpInside)

        for view in [self.titleLabel, self.subLabel, self.statusLabel, self.pill] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.pill.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.pill.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.pill.widthAnchor.constraint(equalToConstant: 58),
            self.pill.heightAnchor.constraint(equalToConstant: 30),

            self.statusLabel.trailingAnchor.constraint(equalTo: self.pill.leadingAnchor, constant: -10),
            self.statusLabel.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.statusLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 110),

            self.titleLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 11),
            self.titleLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),

            self.subLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.subLabel.topAnchor.constraint(equalTo: self.titleLabel.bottomAnchor, constant: 2),
            self.subLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -11),
            self.subLabel.trailingAnchor.constraint(equalTo: self.statusLabel.leadingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    @objc private func pillTapped() { self.onTap?() }

    func show(_ phase: FMXPhase) {
        switch phase {
        case .off:
            self.pill.backgroundColor = .fmxRed
            self.pill.setTitle("", for: .normal)
            self.statusLabel.text = ""
        case .on:
            self.pill.backgroundColor = .fmxGreen
            self.pill.setTitle("", for: .normal)
            self.statusLabel.text = ""
        case .counting(let secondsLeft):
            self.pill.backgroundColor = .fmxAmber
            self.pill.setTitle("\(secondsLeft)", for: .normal)
            self.statusLabel.text = ""
        case .armed:
            self.pill.backgroundColor = .fmxAmber
            self.pill.setTitle("", for: .normal)
            self.statusLabel.text = "Tap to unblock"
        }
    }
}

// MARK: - the wait row

private final class FMXWaitCell: UITableViewCell {
    let label = UILabel()
    let slider = UISlider()
    var onCommit: ((Int) -> Bool)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        self.label.textColor = .label

        self.slider.minimumValue = Float(FMXSwitchStore.minWait)
        self.slider.maximumValue = Float(FMXSwitchStore.maxWait)
        self.slider.isContinuous = true
        self.slider.minimumTrackTintColor = .fmxGreen
        self.slider.addTarget(self, action: #selector(moved), for: .valueChanged)
        self.slider.addTarget(self, action: #selector(released), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        for view in [self.label, self.slider] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }
        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 12),
            self.slider.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.slider.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.slider.topAnchor.constraint(equalTo: self.label.bottomAnchor, constant: 6),
            self.slider.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(seconds: Int) {
        self.label.text = "Unblock wait   \(seconds) s"
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

// MARK: - the screen

final class FMXSwitchesViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case instagram
        case youtube
        case wait
    }

    private let store = FMXSwitchStore.shared
    private var readyAt = [String: Date]()   // deliberately not persisted
    private var ticker: Timer?

    init() {
        super.init(style: .insetGrouped)
        self.title = "Switches"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.largeTitleDisplayMode = .always
        self.navigationController?.navigationBar.prefersLargeTitles = true
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 60

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
        case .wait: return []
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
            guard let section = Section(rawValue: indexPath.section), section != .wait,
                  let cell = self.tableView.cellForRow(at: indexPath) as? FMXSwitchCell else { continue }
            let sw = self.switches(in: section)[indexPath.row]
            cell.show(self.phase(for: sw.key))
        }
        // the lock footer counts down too
        if let footer = self.tableView.footerView(forSection: Section.wait.rawValue) {
            footer.textLabel?.text = self.waitFooter()
            footer.setNeedsLayout()
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
        return section == .wait ? 1 : self.switches(in: section).count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .instagram: return FMXApp.instagram.title
        case .youtube: return FMXApp.youtube.title
        case .wait: return "The wait"
        case nil: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .instagram, .youtube:
            let app = section == Section.instagram.rawValue ? FMXApp.instagram : FMXApp.youtube
            return "Green is blocked, red is allowed. Blocking is instant; unblocking makes you wait, and leaving this screen starts the wait over. Changes apply the next time \(app.title) is opened."
        case .wait:
            return self.waitFooter()
        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }

        if section == .wait {
            let cell = FMXWaitCell(style: .default, reuseIdentifier: nil)
            cell.slider.value = Float(self.store.waitSeconds)
            cell.slider.isEnabled = self.store.waitLockRemaining <= 0
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
        guard let section = Section(rawValue: indexPath.section), section != .wait else { return }
        self.tapped(self.switches(in: section)[indexPath.row])
    }
}
