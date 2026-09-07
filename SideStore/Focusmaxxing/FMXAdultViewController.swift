//
//  FMXAdultViewController.swift
//  Focusmaxxing Hub
//
//  the adult-websites screen, opened from the first row of the switches screen.
//
//  the switch at the top, then one plain list of things to do, then the awkward cases at the
//  bottom. see FMXAdultBlock.swift for why the hub cannot do the blocking itself.
//
//  written the first way (two named "steps", the caveats mixed into the instructions) it was
//  tested on the owner's phone 2026-09-07 and it worked, but their words were: "wasn't always
//  that intuitive, I had to use my brain more", "I have no clue what I'm setting up", "all that
//  jargon below it I find it hard to understand". so: one numbered list from start to finish, the
//  jargon cut, and everything that is only true sometimes moved out of the path and into
//  "If something looks wrong" at the bottom.
//
//  the tick is the customer's own note. the hub has no way to read screen time or the phone's
//  installed profiles, and the screen says so rather than pretending to have checked. until it is
//  ticked, the row on the switches screen is grey, not green, because nothing is blocked yet.
//
//  the screen time wording is apple's own, from the iphone user guide for ios 26 ("Content &
//  Privacy Restrictions", then "App Store, Media, Web, & Games", then "Web Content", then "Limit
//  Adult Websites"). the middle row used to be called "Content Restrictions"; if apple moves it
//  again, the steps here are what needs updating.
//

import UIKit

final class FMXAdultViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case theSwitch
        case setUp
        case trouble
    }

    private enum Row {
        case pill
        case step(String)
        case note(String)      // an aside; it carries no number, so the steps stay 1, 2, 3
        case openSettings
        case installProfile
        case saveProfile
        case checkDNS
        case tick
    }

    private let store = FMXSwitchStore.shared
    private let key = FMXAdultBlock.switchKey
    private var readyAt: Date?     // the countdown, deliberately not persisted
    private var ticker: Timer?
    private var dnsCheckLine: String?   // what the last check said, shown under its button

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
            self.reloadSwitchSection()
        case .on:
            self.readyAt = Date(timeIntervalSinceNow: TimeInterval(self.store.waitSeconds))
        case .counting:
            break
        case .armed:
            self.readyAt = nil
            self.store.setBlocked(false, key: self.key)
            self.reloadSwitchSection()
        }
        self.refreshPill()
    }

    @objc private func tick() { self.refreshPill() }

    private func refreshPill() {
        let indexPath = IndexPath(row: 0, section: Section.theSwitch.rawValue)
        guard let cell = self.tableView.cellForRow(at: indexPath) as? FMXSwitchCell else { return }
        cell.show(self.phase)
    }

    // the words under the switch change once it is allowed
    private func reloadSwitchSection() {
        self.tableView.reloadSections(IndexSet(integer: Section.theSwitch.rawValue), with: .none)
    }

    // MARK: the rows

    private func rows(in section: Section) -> [Row] {
        switch section {
        case .theSwitch:
            return [.pill]

        case .setUp:
            var rows: [Row] = [
                .note("Two things block adult sites on an iPhone: a setting Apple built into it, and a file that sends the phone's web lookups through a filtered server. Do both. It takes about five minutes."),

                .openSettings,
                .step("Tap Open Settings, just above. It lands on this app's own page: tap back until you reach the main Settings list, then scroll down and tap Screen Time."),
                .step("Tap Content & Privacy Restrictions, and turn it on."),
                .step("Tap App Store, Media, Web, & Games."),
                .step("Tap Web Content."),
                .step("Choose Limit Adult Websites."),
                .step("Go back to Screen Time and tap Lock Screen Time Settings."),
                .step("Set four digits. When it offers to set up recovery with your Apple Account, say yes: without that, a passcode you forget is very hard to undo."),
                .step("Come back here and tap Install the private DNS, just below."),

                .installProfile,
                .step("Your browser opens and downloads a file called Focusmaxxing family DNS. If it asks whether to allow it, tap Allow. In some browsers you have to tap the download yourself."),
                .step("Open Settings. Tap Profile Downloaded, near the top."),
                .step("Tap Install at the top right. Type the passcode you unlock the phone with, not the four digits you just made for Screen Time, then keep tapping Install until the phone says Done. Do this within eight minutes of the download."),
                .note("The phone shows the profile in red as unsigned, and warns that the server can see what the phone looks up. Both are normal here: the filtering is the point, and the server is Cloudflare's."),

                .checkDNS,
            ]
            if let line = self.dnsCheckLine {
                rows.append(.note(line))
            }
            rows.append(.tick)
            return rows

        case .trouble:
            return [
                .saveProfile,
                .note("Use that only if your browser would not download the file. Save it, open the Files app, and tap it there."),
                .note("If the phone acts as though it has no internet on some Wi-Fi, that network will not carry the filtered lookups. Settings, then General, then VPN, DNS & Device Management, then DNS, then Automatic switches it off. That is also how the block comes off, so it is friction, not a wall."),
                .note("If the phone will not take the profile while you are away from home, that is Apple's Stolen Device Protection. Do it at home."),
                .note("A VPN app, or iCloud Private Relay, can route around the filtered server."),
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
        case .setUp: return "How to set it up"
        case .trouble: return "If something looks wrong"
        case nil: return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .theSwitch:
            if self.store.isBlocked(self.key) {
                return "Green is blocked, red is allowed. The switch does not block anything by itself: the setup below is the block. The switch is what makes you wait before you undo it."
            }
            return "Allowed. Nothing on the phone changed when you did that. To take the block off for real, undo the setup below: set Web Content back to Unrestricted, and remove the profile."

        case .setUp:
            return "Focusmaxxing Hub can test the private DNS itself, with the button above. It cannot see your Screen Time settings: Apple does not let an app read those. So the tick is your own note, not a check."

        case .trouble, nil:
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
            cell.subLabel.text = "Screen Time and a private DNS"
            cell.show(self.phase)
            cell.onTap = { [weak self] in self?.pillTapped() }
            return cell

        case .step(let text):
            // the number is the position of this step among the steps of its own section; the
            // asides and buttons in between are not counted, so the list reads 1, 2, 3 throughout
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

        case .checkDNS:
            return FMXActionCell(title: "Check the private DNS")

        case .tick:
            return FMXTickCell(title: "I've done all this", ticked: UserDefaults.standard.fmxAdultDone)
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

        case .checkDNS:
            self.checkDNS()

        case .tick:
            UserDefaults.standard.fmxAdultDone.toggle()
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    // MARK: the profile

    // since ios 12.2 the hub cannot hand a profile to the phone itself: it has to arrive through
    // the browser, or as a file the customer taps. this opens the link in whichever browser the
    // phone opens links with, and only safari offers to install what comes back - hence the
    // "save the file instead" row at the bottom, which works whatever the browser is.
    private func installProfile() {
        UIApplication.shared.open(FMXLinks.dnsProfileURL) { [weak self] opened in
            guard !opened else { return }
            DispatchQueue.main.async {
                guard let self else { return }
                debugLog("[FMXAdult] could not open the profile link")
                ToastView(text: "Could not open the link", detailText: "Use \"Save the file instead\" at the bottom.").show(in: self)
            }
        }
    }

    // the one half of this the hub can actually check for itself. see FMXAdultBlock: it asks for a
    // name cloudflare's family server refuses, and looks at what comes back.
    private func checkDNS() {
        self.dnsCheckLine = "Checking…"
        self.reloadSetUpSection()

        FMXAdultBlock.checkFamilyDNS { [weak self] result in
            guard let self else { return }
            switch result {
            case .filtered:
                self.dnsCheckLine = "Working. This phone's lookups are going through the filtered server, so the second half is done. The Screen Time half is not something Focusmaxxing Hub can see."
            case .notFiltered:
                self.dnsCheckLine = "Not working yet. If you have only just installed the profile, give it a minute and check again. Otherwise the profile is not installed, or it is switched off in Settings, under General, then VPN, DNS & Device Management, then DNS."
            case .noAnswer:
                self.dnsCheckLine = "Could not check. The phone may be offline, or on a network that will not carry the lookup."
            }
            self.reloadSetUpSection()
        }
    }

    private func reloadSetUpSection() {
        self.tableView.reloadSections(IndexSet(integer: Section.setUp.rawValue), with: .none)
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

// a numbered instruction, or without a number an aside in grey
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

// the customer's own tick at the end of the list
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
