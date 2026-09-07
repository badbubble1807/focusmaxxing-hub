//
//  FMXAdultViewController.swift
//  Focusmaxxing Hub
//
//  the adult-websites screen, opened from the first row of the switches screen.
//
//  three parts, top to bottom: the switch itself (the same pill as every other switch, with
//  the same wait and the same "leaving this screen starts the wait over" rule), then the two
//  steps that do the actual blocking - apple's screen time restriction, and a dns profile.
//  see FMXAdultBlock.swift for why the hub cannot do this itself.
//
//  the ticks next to each step are the customer's own notes. the hub has no way to read the
//  phone's screen time settings or its installed profiles, and the screen says so rather than
//  pretending to have checked.
//
//  the wording of the screen time steps is apple's own, from the iphone user guide for ios 26
//  ("Content & Privacy Restrictions", then "App Store, Media, Web, & Games", then "Web
//  Content", then "Limit Adult Websites"). the middle row used to be called "Content
//  Restrictions"; if apple moves it again, the steps here are what needs updating.
//

import UIKit

final class FMXAdultViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case theSwitch
        case screenTime
        case dns
    }

    private enum Row {
        case pill
        case step(String)
        case note(String)      // an aside; it carries no step number, so the steps stay 1, 2, 3
        case openSettings
        case installProfile
        case saveProfile
        case screenTimeTick
        case dnsTick
    }

    private let store = FMXSwitchStore.shared
    private let key = FMXAdultBlock.switchKey
    private var readyAt: Date?     // the countdown, deliberately not persisted
    private var ticker: Timer?

    init() {
        super.init(style: .insetGrouped)
        self.title = "Adult websites"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 60

        NotificationCenter.default.addObserver(self, selector: #selector(resetWait), name: UIApplication.didEnterBackgroundNotification, object: nil)
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
        self.resetWait()
    }

    // leaving the screen, or leaving the app, throws the countdown away
    @objc private func resetWait() {
        self.readyAt = nil
        self.refreshPill()
    }

    // MARK: the switch

    private var phase: FMXPhase {
        if !self.store.isBlocked(self.key) { return .off }
        guard let ready = self.readyAt else { return .on }
        let remaining = ready.timeIntervalSinceNow
        if remaining > 0 { return .counting(Int(remaining.rounded(.up))) }
        return .armed
    }

    private func pillTapped() {
        switch self.phase {
        case .off:
            self.store.setBlocked(true, key: self.key)
            self.reloadFooters()
        case .on:
            self.readyAt = Date(timeIntervalSinceNow: TimeInterval(self.store.waitSeconds))
        case .counting:
            break
        case .armed:
            self.readyAt = nil
            self.store.setBlocked(false, key: self.key)
            self.reloadFooters()
        }
        self.refreshPill()
    }

    @objc private func tick() { self.refreshPill() }

    private func refreshPill() {
        let indexPath = IndexPath(row: 0, section: Section.theSwitch.rawValue)
        guard let cell = self.tableView.cellForRow(at: indexPath) as? FMXSwitchCell else { return }
        cell.show(self.phase)
    }

    // the footer under the switch says something different once it is allowed
    private func reloadFooters() {
        self.tableView.reloadSections(IndexSet(integer: Section.theSwitch.rawValue), with: .none)
    }

    // MARK: the rows

    private func rows(in section: Section) -> [Row] {
        switch section {
        case .theSwitch:
            return [.pill]

        case .screenTime:
            return [
                .step("Open Settings, then tap Screen Time."),
                .step("Tap Content & Privacy Restrictions, and turn it on."),
                .step("Tap App Store, Media, Web, & Games."),
                .step("Tap Web Content."),
                .step("Choose Limit Adult Websites."),
                .step("Go back to Screen Time, tap Lock Screen Time Settings, and set four digits. Say yes when it offers to set up recovery with your Apple Account: without that, a Screen Time passcode you forget is very hard to get past."),
                .openSettings,
                .note("Settings opens on this app's own page. Tap back once to reach the main list, then scroll to Screen Time."),
                .screenTimeTick,
            ]

        case .dns:
            return [
                .installProfile,
                .step("Your browser opens and asks whether to allow a profile. Tap Allow, then Close."),
                .step("Open Settings. Tap Profile Downloaded, near the top."),
                .step("Tap Install, type your phone passcode, and tap Install again. Do this within eight minutes, or the phone throws the download away."),
                .note("The phone shows the profile in red as unsigned, and warns that a DNS server can see and filter what the phone looks up. Both are normal here: the filtering is the point, and the server is Cloudflare's."),
                .note("If the phone will not take the profile while you are out, that is Apple's Stolen Device Protection. Do this bit at home, or turn it off first in Settings, under Face ID & Passcode."),
                .saveProfile,
                .note("Use that if your browser only downloaded the file, or showed you a page of code: browsers other than Safari cannot install a profile. Save the file, open the Files app, and tap it there. The phone offers to install it the same way."),
                .dnsTick,
            ]
        }
    }

    // MARK: table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        return self.rows(in: section).count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .theSwitch: return "The switch"
        case .screenTime: return "Step 1: Screen Time"
        case .dns: return "Step 2: a private DNS"
        case nil: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .theSwitch:
            if self.store.isBlocked(self.key) {
                return "Green is blocked, red is allowed. This switch blocks nothing on its own: the two steps below are the block. It is here so that undoing them costs the same wait as every other switch. Blocking is instant; unblocking makes you wait, and leaving this screen starts the wait over."
            }
            return "Allowed. Nothing on the phone changed when you did that. To really take the block off you have to undo both steps yourself: set Web Content back to Unrestricted in Screen Time, and remove the profile in Settings, under General, then VPN, DNS & Device Management."

        case .screenTime:
            return "This is the only block on an iPhone that survives everything else, Focusmaxxing Hub being deleted included. It covers Safari and the other browsers on the phone; it is not a promise about what a particular app shows inside itself.\n\nFocusmaxxing Hub cannot see your Screen Time settings, so the tick is your own note. Apple moves this wording between iOS versions: if a row is not there, take the closest match."

        case .dns:
            return "This sends the phone's website lookups to Cloudflare's family server, which turns down adult and malware sites. It covers the whole phone, not only the browser, and it keeps working if Focusmaxxing Hub is deleted. A VPN app or iCloud Private Relay can route around it.\n\nSome hotel and office Wi-Fi will not carry encrypted lookups, and the phone then looks as though it has no internet. One switch fixes that, and it is the same switch that takes the block off again: Settings, then General, then VPN, DNS & Device Management, then DNS, then Automatic. So it is friction, not a wall.\n\nFocusmaxxing Hub cannot see whether the profile is installed, so the tick is your own note."

        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let rows = self.rows(in: section)
        let row = rows[indexPath.row]

        switch row {
        case .pill:
            let cell = FMXSwitchCell(style: .default, reuseIdentifier: nil)
            cell.titleLabel.text = "Adult websites"
            cell.subLabel.text = "Blocking is instant; unblocking makes you wait"
            cell.show(self.phase)
            cell.onTap = { [weak self] in self?.pillTapped() }
            return cell

        case .step(let text):
            // the number is the position of this step among the steps of its own section; the
            // asides in between are not counted, so the numbers a person follows stay 1, 2, 3
            let number = rows.prefix(indexPath.row + 1).filter { if case .step = $0 { return true } else { return false } }.count
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: number, text: text)
            return cell

        case .note(let text):
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: nil, text: text)
            return cell

        case .openSettings:
            return FMXActionCell(title: "Open Settings")

        case .installProfile:
            return FMXActionCell(title: "Install the private DNS")

        case .saveProfile:
            return FMXActionCell(title: "Save the file instead")

        case .screenTimeTick:
            return FMXTickCell(title: "I've done this on this phone", ticked: UserDefaults.standard.fmxAdultScreenTimeDone)

        case .dnsTick:
            return FMXTickCell(title: "I've done this on this phone", ticked: UserDefaults.standard.fmxAdultDNSDone)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let section = Section(rawValue: indexPath.section) else { return }
        let row = self.rows(in: section)[indexPath.row]

        switch row {
        case .pill:
            self.pillTapped()

        case .step, .note:
            break

        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)

        case .installProfile:
            self.installProfile()

        case .saveProfile:
            self.saveProfile(from: tableView.cellForRow(at: indexPath))

        case .screenTimeTick:
            UserDefaults.standard.fmxAdultScreenTimeDone.toggle()
            tableView.reloadRows(at: [indexPath], with: .none)

        case .dnsTick:
            UserDefaults.standard.fmxAdultDNSDone.toggle()
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    // MARK: the profile

    // since ios 12.2 the hub cannot hand a profile to the phone itself: it has to arrive through
    // the browser, or as a file the customer taps. this opens the link in whichever browser the
    // phone opens links with, and only safari offers to install what comes back - hence the
    // "save the file instead" row underneath, which works whatever the browser is.
    private func installProfile() {
        UIApplication.shared.open(FMXLinks.dnsProfileURL) { [weak self] opened in
            guard !opened else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                debugLog("[FMXAdult] could not open the profile link")
                ToastView(text: "Could not open the link", detailText: "Use \"Save the file instead\" below.").show(in: self)
            }
        }
    }

    private func saveProfile(from cell: UITableViewCell?) {
        guard let url = FMXAdultBlock.writeProfileToTemporaryFile() else {
            ToastView(text: "Could not save the file", detailText: "There may be no room left on the phone.").show(in: self)
            return
        }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let cell {
            share.popoverPresentationController?.sourceView = cell
            share.popoverPresentationController?.sourceRect = cell.bounds
        }
        self.present(share, animated: true)
    }
}

// MARK: - the rows this screen adds

// a numbered instruction
private final class FMXStepCell: UITableViewCell {
    private let numberLabel = UILabel()
    private let textView = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none

        self.numberLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        self.numberLabel.textColor = .altPrimary
        self.numberLabel.textAlignment = .center
        self.numberLabel.setContentHuggingPriority(.required, for: .horizontal)
        self.numberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        self.textView.font = .preferredFont(forTextStyle: .subheadline)
        self.textView.textColor = .label
        self.textView.numberOfLines = 0

        for view in [self.numberLabel, self.textView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.numberLabel.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.numberLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 11),
            self.numberLabel.widthAnchor.constraint(equalToConstant: 22),

            self.textView.leadingAnchor.constraint(equalTo: self.numberLabel.trailingAnchor, constant: 8),
            self.textView.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.textView.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 11),
            self.textView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -11),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    // no number means an aside rather than a step: the text keeps the same left edge as the
    // steps above it, so the column still reads as one list.
    func show(number: Int?, text: String) {
        self.numberLabel.text = number.map { "\($0)." } ?? ""
        self.textView.text = text
        self.textView.textColor = (number == nil) ? UIColor.secondaryLabel : UIColor.label
    }
}

// a row that does something when tapped
private final class FMXActionCell: UITableViewCell {
    private let label = UILabel()

    init(title: String) {
        super.init(style: .default, reuseIdentifier: nil)

        self.label.font = .systemFont(ofSize: 16, weight: .semibold)
        self.label.textColor = .altPrimary
        self.label.text = title
        self.label.numberOfLines = 0
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.label)

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 13),
            self.label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -13),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}

// the customer's own tick next to a step
private final class FMXTickCell: UITableViewCell {
    private let label = UILabel()

    init(title: String, ticked: Bool) {
        super.init(style: .default, reuseIdentifier: nil)

        self.label.font = .systemFont(ofSize: 16, weight: .regular)
        self.label.textColor = ticked ? .secondaryLabel : .label
        self.label.text = title
        self.label.numberOfLines = 0
        self.label.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.addSubview(self.label)

        self.accessoryType = ticked ? .checkmark : .none

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 13),
            self.label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -13),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
