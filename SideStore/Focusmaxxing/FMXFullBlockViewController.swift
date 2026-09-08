//
//  FMXFullBlockViewController.swift
//  Focusmaxxing Hub
//
//  the guided "Full block" screen, one screen for every app. it is FMXAdultViewController with the
//  DNS half taken out: one set of Screen Time steps, then the customer's tick. it is pushed from a
//  fold's "Full block" row on the switches screen (Instagram, YouTube and the six single apps) and
//  from a row in the Custom blocks pane; the app's name comes in through init, so the wording is
//  the same code for all of them.
//
//  the same honesty as the NSFW screen: the hub cannot block an app itself on a free apple account,
//  so it guides and the phone blocks, behind the Screen Time passcode. the tick is the customer's
//  own note - nothing here reads Screen Time - so until it is ticked the fold's row is grey, not on.
//  no line claims the hub blocked anything. see FMXFullBlock.swift for why this is a tick and not a
//  switch.
//

import UIKit

final class FMXFullBlockViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case steps
        case trouble
    }

    private enum Row {
        case openSettings
        case step(String)
        case note(String)      // an aside; no number, so the steps stay 1, 2, 3
        case tick
    }

    private let app: FMXFullBlockApp

    // which rows have already risen into place this visit; a row only repainted does not slide in again
    private var arrived = Set<IndexPath>()
    private var entranceUntil = Date.distantPast

    init(app: FMXFullBlockApp) {
        self.app = app
        super.init(style: .insetGrouped)
        self.title = "Block \(app.name)"
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        FMXTheme.style(navigationItem: self.navigationItem)
        FMXTheme.style(tableView: self.tableView)
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 56
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.arrived.removeAll()
        self.entranceUntil = Date(timeIntervalSinceNow: 0.5)
        self.tableView.reloadData()
    }

    // MARK: the rows

    private func rows(in section: Section) -> [Row] {
        switch section {
        case .steps:
            var rows: [Row] = [.openSettings]
            for step in FMXFullBlock.steps(for: self.app.name) { rows.append(.step(step)) }
            rows.append(.tick)
            return rows

        case .trouble:
            return [
                .note("To undo it, remove the limit in Screen Time. That needs the passcode you set."),
                .note("An app limit resets each day, so \(self.app.name) opens for a minute before it locks again."),
                .note("No Screen Time passcode yet? Set one, or the block lifts with a tap."),
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
        switch Section(rawValue: section) {
        case .steps: return FMXSectionHeader(title: "Block \(self.app.name) in Screen Time")
        case .trouble: return FMXSectionHeader(title: "If something looks wrong")
        case nil: return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return FMXSectionHeader.height
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .steps:
            return "The Hub can't block an app by itself. These steps put \(self.app.name) behind your Screen Time passcode, which is the one block that survives even the Hub being deleted."
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
        case .openSettings:
            return FMXActionCell(title: "Open Settings", symbol: "gearshape")

        case .step(let text):
            // the number is this step's place among the steps of its section; the buttons in
            // between are not counted, so the list reads 1, 2, 3
            let number = rows.prefix(indexPath.row + 1).filter { if case .step = $0 { return true } else { return false } }.count
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: number, text: text)
            return cell

        case .note(let text):
            let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
            cell.show(number: nil, text: text)
            return cell

        case .tick:
            return FMXTickCell(title: "I've blocked \(self.app.name) in Screen Time", ticked: FMXFullBlock.isSetUp(self.app.id))
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard let section = Section(rawValue: indexPath.section) else { return }
        let row = self.rows(in: section)[indexPath.row]

        switch row {
        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)

        case .step, .note:
            break

        case .tick:
            FMXFullBlock.setSetUp(!FMXFullBlock.isSetUp(self.app.id), for: self.app.id)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
}
