//
//  FMXAdultViewController.swift
//  Focusmaxxing Hub
//
//  the NSFW screen, opened from the first row of the switches screen.
//
//  the switch at the top, then two steps, then the awkward cases at the bottom. see
//  FMXAdultBlock.swift for why the hub cannot do the blocking itself.
//
//  this screen has now been cut twice by the owner, both times for the same reason.
//  2026-09-07, after doing it on their own phone: "wasn't always that intuitive, I had to use my
//  brain more", "I have no clue what I'm setting up", "all that jargon below it I find it hard to
//  understand". 2026-09-08, looking at the rewrite: "theres just SO MUCH text bro ... a beginners
//  gonna get overwhelmed by all this text, im literally just setting up nsfw blocks by setting up
//  screen time and installing private [dns]".
//
//  so the shape is now: two numbered steps, each with its own button at the top of it and no line
//  longer than one sentence. Everything that is only true sometimes is at the bottom under "If
//  something looks wrong". If you are tempted to add a paragraph here, put it there instead - or
//  leave it out.
//
//  the tick is the customer's own note. the hub has no way to read screen time, and the screen
//  says so in one line rather than pretending to have checked. until it is ticked, the row on the
//  switches screen is grey, not green, because nothing is blocked yet.
//
//  the screen time wording is apple's own, from the iphone user guide for ios 26 ("Content &
//  Privacy Restrictions", then "App Store, Media, Web, & Games", then "Web Content", then "Limit
//  Adult Websites"). if apple moves it again, these steps are what needs updating.
//

import UIKit

final class FMXAdultViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case theSwitch
        case screenTime
        case dns
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

    // which rows have already risen into place this visit; a row that is only repainted does not
    // slide in again
    private var arrived = Set<IndexPath>()

    // and only while the screen is opening; see the same pair on the switches screen
    private var entranceUntil = Date.distantPast

    init() {
        super.init(style: .insetGrouped)
        self.title = "Block NSFW"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        FMXTheme.style(navigationItem: self.navigationItem)
        FMXTheme.style(tableView: self.tableView)
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 56

        NotificationCenter.default.addObserver(self, selector: #selector(resetWait), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.arrived.removeAll()
        self.entranceUntil = Date(timeIntervalSinceNow: 0.5)
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

    // the line under the switch changes once it is allowed
    private func reloadSwitchSection() {
        self.tableView.reloadSections(IndexSet(integer: Section.theSwitch.rawValue), with: .none)
    }

    // MARK: the rows

    private func rows(in section: Section) -> [Row] {
        switch section {
        case .theSwitch:
            return [.pill]

        case .screenTime:
            return [
                .openSettings,
                .step("Tap back until you reach the main Settings list, then tap Screen Time."),
                .step("Tap Content & Privacy Restrictions and turn it on."),
                .step("Tap App Store, Media, Web, & Games, then Web Content."),
                .step("Choose Limit Adult Websites."),
                .step("Back in Screen Time, tap Lock Screen Time Settings and set four digits."),
            ]

        case .dns:
            var rows: [Row] = [
                .installProfile,
                .step("Your browser downloads a file. Tap Allow if it asks."),
                .step("Open Settings and tap Profile Downloaded, near the top."),
                .step("Tap Install, type the passcode you unlock the phone with, and keep tapping Install."),
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
                .note("Use that if your browser would not download the file. Save it, then tap it in the Files app."),
                .note("No internet on some Wi-Fi? Settings, General, VPN, DNS & Device Management, DNS, Automatic. That is also how the block comes off."),
                .note("A VPN app, or iCloud Private Relay, can go around it."),
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

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title: String
        switch Section(rawValue: section) {
        case .theSwitch: return nil
        case .screenTime: title = "Step 1: Screen Time"
        case .dns: title = "Step 2: Private DNS"
        case .trouble: title = "If something looks wrong"
        case nil: return nil
        }
        return FMXSectionHeader(title: title)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return Section(rawValue: section) == .theSwitch ? 8 : FMXSectionHeader.height
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .theSwitch:
            if self.store.isBlocked(self.key) {
                return "The switch is the wait. The two steps below are what does the blocking."
            }
            return "Allowed here, but the phone is still set up. To really unblock, undo the two steps below."

        case .screenTime:
            return "Say yes when it offers recovery: a passcode you forget is very hard to undo."

        case .dns:
            return "The phone calls the profile unsigned and says the server can see what you look up. Both are normal — the server is Cloudflare's. The Hub can check this half, but not Screen Time, so the tick is your own note."

        case .trouble, nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard let footer = view as? UITableViewHeaderFooterView else { return }
        var configuration = footer.defaultContentConfiguration()
        configuration.text = self.tableView(tableView, titleForFooterInSection: section)
        configuration.textProperties.font = FMXFont.of(12.5, .regular)
        configuration.textProperties.color = FMXTheme.faint
        configuration.textProperties.numberOfLines = 0
        footer.contentConfiguration = configuration
    }

    // the rows rise into place one after another the first time they are seen on a visit
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard self.arrived.insert(indexPath).inserted, Date() < self.entranceUntil else { return }
        FMXEntrance.play(on: cell, ordinal: self.arrived.count - 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UITableViewCell() }
        let rows = self.rows(in: section)
        let row = rows[indexPath.row]

        switch row {
        case .pill:
            let cell = FMXSwitchCell(style: .default, reuseIdentifier: nil)
            cell.titleLabel.text = "Block NSFW"
            cell.show(self.phase)
            cell.onTap = { [weak self] in self?.pillTapped() }
            return cell

        case .step(let text):
            // the number is the position of this step among the steps of its own section; the
            // buttons in between are not counted, so each step list reads 1, 2, 3
            let number = rows.prefix(indexPath.row + 1).filter { if case .step = $0 { return true } else { return false } }.count
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: number, text: text)
            return cell

        case .note(let text):
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: nil, text: text)
            return cell

        case .openSettings:
            return FMXActionCell(title: "Open Settings", symbol: "gearshape")

        case .installProfile:
            return FMXActionCell(title: "Install the private DNS", symbol: "arrow.down.circle")

        case .saveProfile:
            return FMXActionCell(title: "Save the file instead", symbol: "square.and.arrow.up")

        case .checkDNS:
            return FMXActionCell(title: "Check it worked", symbol: "checkmark.shield")

        case .tick:
            return FMXTickCell(title: "I've done both steps", ticked: UserDefaults.standard.fmxAdultDone)
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

    // the one half the hub can actually check. see FMXAdultBlock: it asks for a name cloudflare's
    // family server refuses, and looks at what comes back.
    private func checkDNS() {
        self.dnsCheckLine = "Checking…"
        self.reloadDNSSection()

        FMXAdultBlock.checkFamilyDNS { [weak self] result in
            guard let self else { return }
            switch result {
            case .filtered:
                self.dnsCheckLine = "Working. This phone's lookups go through the filtered server."
            case .notFiltered:
                self.dnsCheckLine = "Not working yet. If you have only just installed it, wait a minute and check again."
            case .noAnswer:
                self.dnsCheckLine = "Could not check. The phone may be offline."
            }
            self.reloadDNSSection()
        }
    }

    private func reloadDNSSection() {
        self.tableView.reloadSections(IndexSet(integer: Section.dns.rawValue), with: .none)
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

// the numbered-step, action and tick rows this screen is built from now live in FMXControls.swift,
// shared with FMXFullBlockViewController.
