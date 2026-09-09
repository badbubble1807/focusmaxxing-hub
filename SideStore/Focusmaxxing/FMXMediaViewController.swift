//
//  FMXMediaViewController.swift
//  Focusmaxxing Hub
//
//  the block media screen: what plays on the block screen inside Custom blocked Instagram and
//  Custom blocked YouTube, under the message. add a picture, a GIF, a clip or a sound; the block
//  screen shows one of them at random.
//
//  it is pushed from the "Block screen" card at the bottom of the switches screen. the files live
//  in the shared app-group folder (FMXMediaStore) where the two apps read them.
//
//  this is a phone-only list. nothing carries files from the computer yet, so what is added on the
//  desktop stays on the desktop and what is added here stays here (CHECKLIST.md, section C).
//

import UIKit
import PhotosUI
import UniformTypeIdentifiers

final class FMXMediaViewController: UITableViewController {
    private enum Section: Int, CaseIterable {
        case add
        case list
    }

    private var media: [URL] = []

    private var arrived = Set<IndexPath>()
    private var entranceUntil = Date.distantPast

    init() {
        super.init(style: .insetGrouped)
        self.title = "Block screen"
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
        self.reload(entrance: true)
    }

    /// entrance:true lets the rows rise into place, which is right on arriving at the screen and
    /// wrong in the middle of using it - a row removed should not restage the whole list.
    private func reload(entrance: Bool) {
        self.media = FMXMediaStore.list()
        self.arrived.removeAll()
        self.entranceUntil = entrance ? Date(timeIntervalSinceNow: 0.5) : Date.distantPast
        self.tableView.reloadData()
    }

    // MARK: table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .add:  return 2
        // one empty-state row when there is nothing yet, so the screen never looks broken
        case .list: return max(self.media.count, 1)
        case nil:   return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch Section(rawValue: section) {
        case .add:  return FMXSectionHeader(title: "Add")
        case .list: return FMXSectionHeader(title: "On the block screen")
        case nil:   return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return FMXSectionHeader.height
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .add:
            return "When Instagram or YouTube is fully blocked, the screen shows your mark, one of your messages, and one of these at random. Up to \(FMXMediaStore.maxCount), and \(FMXMediaStore.maxBytes / (1024 * 1024)) MB each."
        case .list:
            return "These live on this phone. Media added on the computer stays there for now. Swipe a row to remove it."
        case nil:
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

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard self.arrived.insert(indexPath).inserted, Date() < self.entranceUntil else { return }
        FMXEntrance.play(on: cell, ordinal: self.arrived.count - 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .add:
            return indexPath.row == 0
                ? FMXActionCell(title: "Add from photos", symbol: "photo.on.rectangle")
                : FMXActionCell(title: "Add a file", symbol: "folder")

        case .list:
            if self.media.isEmpty {
                let cell = FMXStepCell(style: .default, reuseIdentifier: nil)
                cell.show(number: nil, text: "Nothing yet. The block screen shows your message on its own until you add something.")
                return cell
            }
            let url = self.media[indexPath.row]
            return FMXMediaCell(title: FMXMediaStore.kindName(for: url), thumbnail: FMXMediaStore.thumbnail(for: url))

        case nil:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        guard Section(rawValue: indexPath.section) == .add else { return }
        if indexPath.row == 0 { self.addFromPhotos() } else { self.addFromFiles() }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .list, !self.media.isEmpty else { return nil }
        let url = self.media[indexPath.row]
        let remove = UIContextualAction(style: .destructive, title: "Remove") { [weak self] _, _, done in
            FMXMediaStore.remove(url)
            self?.reload(entrance: false)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }

    // MARK: adding

    private func addFromPhotos() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .any(of: [.images, .videos])
        configuration.selectionLimit = 0
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func addFromFiles() {
        // every type we can play, worked out from the extensions rather than listed twice
        let types = FMXMediaStore.allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = self
        self.present(picker, animated: true)
    }

    private func saved(data: Data, extension ext: String) {
        if let problem = FMXMediaStore.add(data: data, extension: ext) {
            self.say(problem)
        }
        self.reload(entrance: false)
    }

    // picking several at once can turn several of them down in a row; only the first is said,
    // because presenting an alert on top of an alert quietly does nothing at all.
    private func say(_ message: String) {
        guard self.presentedViewController == nil else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}

// MARK: - the two pickers

extension FMXMediaViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        for result in results {
            let provider = result.itemProvider
            // the first type this item offers that an iPhone can also play back
            let identifier = provider.registeredTypeIdentifiers.first { id in
                guard let type = UTType(id), let ext = type.preferredFilenameExtension else { return false }
                return FMXMediaStore.allowedExtensions.contains(ext.lowercased())
            }
            guard let identifier, let ext = UTType(identifier)?.preferredFilenameExtension else { continue }

            // the url is only alive inside this block, so the bytes are taken here and now
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, _ in
                guard let url, let data = try? Data(contentsOf: url) else { return }
                DispatchQueue.main.async { self?.saved(data: data, extension: ext) }
            }
        }
    }
}

extension FMXMediaViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        for url in urls {
            let opened = url.startAccessingSecurityScopedResource()
            defer { if opened { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            self.saved(data: data, extension: url.pathExtension)
        }
    }
}

// MARK: - one row

final class FMXMediaCell: FMXCell {
    private let label = UILabel()
    private let picture = UIImageView()

    init(title: String, thumbnail: UIImage?) {
        super.init(style: .default, reuseIdentifier: nil)

        self.picture.image = thumbnail
        self.picture.tintColor = FMXTheme.accentText
        self.picture.contentMode = .scaleAspectFill
        self.picture.clipsToBounds = true
        self.picture.layer.cornerRadius = 8
        self.picture.backgroundColor = FMXTheme.surfaceHigh

        self.label.font = FMXFont.of(16, .semibold)
        self.label.textColor = FMXTheme.text
        self.label.text = title

        for view in [self.picture, self.label] {
            view.translatesAutoresizingMaskIntoConstraints = false
            self.contentView.addSubview(view)
        }

        let margins = self.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            self.picture.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            self.picture.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.picture.widthAnchor.constraint(equalToConstant: 38),
            self.picture.heightAnchor.constraint(equalToConstant: 38),

            self.label.leadingAnchor.constraint(equalTo: self.picture.trailingAnchor, constant: 12),
            self.label.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            self.label.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 14),
            self.label.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }
}
