//
//  BrowseViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Combine
import CoreData
@preconcurrency import Nuke

class BrowseViewController: UICollectionViewController
{
    // Nil == Show apps from all sources.
    let source: Source?

    // focusmaxxing hub: true when this screen is the "Apps" tab, showing the built-in list only
    var isFocusmaxxingList: Bool {
        return self.source?.identifier == Source.altStoreIdentifier
    }

    private(set) var category: StoreCategory? {
        didSet {
            self.updateDataSource()
            self.update()
        }
    }
    
    var searchPredicate: NSPredicate? {
        didSet {
            self.updateDataSource()
        }
    }
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var placeholderView = RSTPlaceholderView(frame: .zero)
    
    private let prototypeCell = AppCardCollectionViewCell(frame: .zero)
    private var sortButton: UIBarButtonItem?
    
    private var preferredAppSorting: AppSorting = UserDefaults.standard.preferredAppSorting
    
    private var cancellables = Set<AnyCancellable>()
    
    private var titleStackView: UIStackView!
    private var titleSourceIconView: AppIconImageView!
    private var titleCategoryIconView: UIImageView!
    private var titleLabel: UILabel!
    
    init?(source: Source?, coder: NSCoder)
    {
        self.source = source
        self.category = nil
        
        super.init(coder: coder)
    }
    
    init?(category: StoreCategory?, coder: NSCoder)
    {
        self.source = nil
        self.category = category
        
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder)
    {
        self.source = nil
        self.category = nil
        
        super.init(coder: coder)
    }
    
    private var cachedItemSizes = [String: CGSize]()
    
    @IBOutlet private var sourcesBarButtonItem: UIBarButtonItem!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.backgroundColor = .altBackground
        // focusmaxxing hub: the same ground, with the accent glowing behind the top of it, that
        // the switches screen stands on
        self.collectionView.backgroundView = FMXTheme.backdrop()
        self.collectionView.alwaysBounceVertical = true
        
        self.dataSource.searchController.searchableKeyPaths = [#keyPath(StoreApp.name),
                                                               #keyPath(StoreApp.subtitle),
                                                               #keyPath(StoreApp.developerName),
                                                               #keyPath(StoreApp.bundleIdentifier)]
        #if !os(tvOS)
        // focusmaxxing hub: the built-in list is two apps; no search box over it
        if !self.isFocusmaxxingList
        {
            self.navigationItem.searchController = self.dataSource.searchController
        }
        #endif

        self.prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(AppCardCollectionViewCell.self, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        let collectionViewLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.minimumLineSpacing = 30
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        self.collectionView.refreshControl = refreshControl
        #endif
        
        #if !os(tvOS)
        if self.category != nil, #available(iOS 16, *)
        {
            let categoriesMenu = UIMenu(children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    let actions = self?.makeCategoryActions() ?? []
                    completion(actions)
                }
            ])
            
            self.navigationItem.titleMenuProvider = { _ in categoriesMenu }
        }
        #endif
        
        self.titleSourceIconView = AppIconImageView(style: .circular)
        
        self.titleCategoryIconView = UIImageView(frame: .zero)
        self.titleCategoryIconView.contentMode = .scaleAspectFit
        
        self.titleLabel = UILabel()
        self.titleLabel.font = FMXFont.of(17, .bold)
        self.titleLabel.textColor = FMXTheme.text
        
        self.titleStackView = UIStackView(arrangedSubviews: [self.titleSourceIconView, self.titleCategoryIconView, self.titleLabel])
        self.titleStackView.spacing = 4
        self.titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 16, *)
        {
            self.navigationItem.preferredSearchBarPlacement = .automatic
        }
        #endif
        
        self.prepareAppSorting()
        
        self.preparePipeline()
        
        NSLayoutConstraint.activate([
            // Source icon = equal width and height
            self.titleSourceIconView.heightAnchor.constraint(equalToConstant: 26),
            self.titleSourceIconView.widthAnchor.constraint(equalTo: self.titleSourceIconView.heightAnchor),
            
            // Category icon = constant height, variable widths
            self.titleCategoryIconView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        self.updateDataSource()
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        self.update()

        // a day may have passed while this tab was not the one on screen. only the countdown is
        // redrawn, never the whole list: reloading would throw away the progress bar of an install
        // that is still running behind it.
        self.fmxRefreshDaysLeft()
    }
    
    override func viewDidDisappear(_ animated: Bool) 
    {
        super.viewDidDisappear(animated)
        
        self.navigationController?.navigationBar.tintColor = nil
    }
}

private extension BrowseViewController
{
    func preparePipeline()
    {
        AppManager.shared.$updateSourcesResult
            .receive(on: RunLoop.main) // Delay to next run loop so we receive _current_ value (not previous value).
            .sink { [weak self] result in
                self?.update()
            }
            .store(in: &self.cancellables)
    }
    
    // focusmaxxing hub: the same rule as upstream's StoreApp.visibleAppsPredicate, minus the clause
    // that hides the store's own app from every list. our app list carries the hub itself so it can
    // offer its own updates; with upstream's rule the hub's tile was never drawn, and since this
    // fork does not use the My Apps "Updates" section either, there was no way at all to move the
    // hub to a new version from inside the app - it had to be fetched by hand in Safari.
    // only the pinned-source list uses this; every other list keeps upstream's rule.
    var fmxOwnSourcePredicate: NSPredicate {
        return NSPredicate(format: "(%K == NO) OR (%K == NO) OR (%K == YES)",
                           #keyPath(StoreApp.isPledgeRequired),
                           #keyPath(StoreApp.isHiddenWithoutPledge),
                           #keyPath(StoreApp.isPledged))
    }

    func makeFetchRequest() -> NSFetchRequest<StoreApp>
    {
        let fetchRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        fetchRequest.returnsObjectsAsFaults = false

        let predicate = self.source != nil ? self.fmxOwnSourcePredicate : StoreApp.visibleAppsPredicate

        if let source = self.source
        {
            let filterPredicate = NSPredicate(format: "%K == %@", #keyPath(StoreApp._source), source)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filterPredicate, predicate])
        }
        else if let category = self.category
        {
            let categoryPredicate = switch category {
            case .other: StoreApp.otherCategoryPredicate
            default: NSPredicate(format: "%K == %@", #keyPath(StoreApp._category), category.rawValue)
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [categoryPredicate, predicate])
        }
        else
        {
            fetchRequest.predicate = predicate
        }
        
        var sortDescriptors = [NSSortDescriptor(keyPath: \StoreApp.name, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.bundleIdentifier, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.sourceIdentifier, ascending: true)]
        
        switch self.preferredAppSorting
        {
        case .default:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.sortIndex, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .name:
            // Already sorting by name, no need to prepend additional sort descriptor.
            break
            
        case .developer:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.developerName, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .lastUpdated:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.latestSupportedVersion?.date, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
        }
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        return fetchRequest
    }
    
    func makeDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>
    {
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: context)
        dataSource.placeholderView = self.placeholderView

        // focusmaxxing hub: the first thing anybody sees on a cold launch, while the list is still
        // being fetched. it was grey system type over a black screen with a grey spinner.
        self.placeholderView.textLabel.font = FMXFont.of(22, .heavy)
        self.placeholderView.textLabel.textColor = FMXTheme.text
        self.placeholderView.detailTextLabel.font = FMXFont.of(15, .regular)
        self.placeholderView.detailTextLabel.textColor = FMXTheme.muted
        self.placeholderView.activityIndicatorView.color = FMXTheme.teal
        dataSource.cellConfigurationHandler = { [weak self] (cell, app, indexPath) in
            guard let self else { return }
            
            let cell = cell as! AppCardCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            let showSourceIcon = (self.source == nil) // Hide source icon if redundant
            cell.configure(for: app, showSourceIcon: showSourceIcon)
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            
            // focusmaxxing hub: our own tile is drawn so it can offer its own update (see
            // fmxOwnSourcePredicate). there is no Open for it - that button would ask iOS to open
            // the app you are already looking at, and nothing would happen - so the button is
            // there only when there is an update. set both ways: a reused cell must not keep it
            // hidden for a different app.
            cell.bannerView.button.isHidden = (app.bundleIdentifier == StoreApp.altstoreAppID) && !(app.installedApp?.hasUpdate ?? false)

            cell.bannerView.button.addTarget(self, action: #selector(BrowseViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.activityIndicatorView.style = .medium
            cell.bannerView.button.activityIndicatorView.color = .white
            
            // focusmaxxing hub: one accent on every tile. an app's own brand colour (Instagram pink,
            // YouTube red) made this tab read as three unrelated shops.
            let tintColor = FMXTheme.volt
            cell.tintColor = tintColor

            // and how long this one has left, which used to be on a tab of its own
            self.fmxShowDaysLeft(on: cell, for: app)
        }
        dataSource.prefetchHandler = { (storeApp, indexPath, completionHandler) in
            let iconURL = storeApp.iconURL
            let imageTask = ImagePipeline.shared.loadImage(with: iconURL, progress: nil) { result in
                switch result
                {
                case .success(let response):
                    let image = response.image
                    DispatchQueue.global(qos: .userInitiated).async {
                        _ = image.isPredominantlyLight
                        _ = image.withDropShadow(color: .black, radius: 4, offset: CGSize(width: 0, height: 1.5), opacity: 0.25)
                        DispatchQueue.main.async {
                            completionHandler(image, nil)
                        }
                    }
                case .failure(let error): completionHandler(nil, error)
                }
            }
            return Task {
                await withTaskCancellationHandler {
                    if Task.isCancelled {
                        imageTask.cancel()
                    }
                } onCancel: {
                    imageTask.cancel()
                }
            }
        }
        dataSource.prefetchCompletionHandler = { [weak dataSource] (cell, image, indexPath, error) in
            let cell = cell as! AppCardCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            
            if let error = error, let dataSource
            {
                let app = dataSource.item(at: indexPath)
                debugLog("Failed to load app icon from \(app.iconURL). \(error.localizedDescription)")
            }
        }
        
        return dataSource
    }
    
    func updateDataSource()
    {
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.dataSource.fetchedResultsController = fetchedResultsController
        
        self.dataSource.predicate = self.searchPredicate
    }
    
    func updateSources()
    {
        AppManager.shared.updateAllSources { result in
            #if !os(tvOS)
            self.collectionView.refreshControl?.endRefreshing()
            #endif
            
            guard case .failure(let error) = result else { return }
            
            if self.dataSource.itemCount > 0
            {
                let toastView = ToastView(error: error)
                toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                toastView.show(in: self)
            }
        }
    }
    
    func update()
    {
        if self.searchPredicate != nil
        {
            self.placeholderView.textLabel.text = NSLocalizedString("No apps", comment: "")
            self.placeholderView.textLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure your spelling is correct, or try searching for another app.", comment: "")
            self.placeholderView.detailTextLabel.isHidden = false
            
            self.placeholderView.activityIndicatorView.stopAnimating()
        }
        else
        {
            switch AppManager.shared.updateSourcesResult
            {
            case nil:
                self.placeholderView.textLabel.isHidden = true
                self.placeholderView.detailTextLabel.isHidden = false
                
                self.placeholderView.detailTextLabel.text = NSLocalizedString("Loading…", comment: "")
                
                self.placeholderView.activityIndicatorView.startAnimating()
                
            case .failure(let error):
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = false
                
                self.placeholderView.textLabel.text = NSLocalizedString("Unable to fetch apps", comment: "")
                self.placeholderView.detailTextLabel.text = error.localizedDescription
                
                self.placeholderView.activityIndicatorView.stopAnimating()
                
            case .success:
                self.placeholderView.textLabel.text = NSLocalizedString("No apps", comment: "")
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = true
                
                self.placeholderView.activityIndicatorView.stopAnimating()
            }
        }
        
        let tintColor: UIColor
        
        if let source = self.source
        {
            tintColor = source.effectiveTintColor?.adjustedForDisplay ?? .altPrimary

            // focusmaxxing hub: the built-in list is the "Apps" tab, not a source with a name
            self.title = self.isFocusmaxxingList ? "Apps" : source.name

            self.titleSourceIconView.backgroundColor = tintColor
            // focusmaxxing hub: our own list is the tab itself, not a shop with a badge - the
            // heading is the word "Apps", set like every other heading in the product
            self.titleSourceIconView.isHidden = self.isFocusmaxxingList

            self.titleCategoryIconView.isHidden = true
            
            if let iconURL = source.effectiveIconURL
            {
                Nuke.loadImage(with: iconURL, into: self.titleSourceIconView) { result in
                    switch result
                    {
                    case .failure(let error): debugLog("Failed to fetch source icon at \(iconURL). \(error.localizedDescription)")
                    case .success: self.titleSourceIconView.backgroundColor = .white
                    }
                }
            }
        }
        else if let category = self.category
        {
            tintColor = category.tintColor
            
            self.title = category.localizedName
            
            let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
            self.titleCategoryIconView.image = image
            self.titleCategoryIconView.isHidden = false
            
            self.titleSourceIconView.isHidden = true
        }
        else
        {
            tintColor = .altPrimary
            
            self.title = NSLocalizedString("Browse", comment: "")
            
            self.titleSourceIconView.isHidden = true
            self.titleCategoryIconView.isHidden = true
        }
        
        self.titleLabel.text = self.title
        self.titleStackView.sizeToFit()
        self.navigationItem.titleView = self.titleStackView
        
        // focusmaxxing hub: one accent, whatever the app's own colour is. this runs on every
        // update, so the bar has to be set here rather than once in viewDidLoad or it is put back.
        self.view.tintColor = FMXTheme.teal

        #if !os(tvOS)
        FMXTheme.style(navigationItem: self.navigationItem)
        #endif

        // Necessary to tint UISearchController's inline bar button.
        self.navigationController?.navigationBar.tintColor = FMXTheme.teal
        
        if let sortButton
        {
            sortButton.image = sortButton.image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
    }
    
    func makeCategoryActions() -> [UIAction]
    {
        let handler = { [weak self] (category: StoreCategory) in
            self?.category = category
        }
        
        let fetchRequest = NSFetchRequest(entityName: StoreApp.entity().name!) as NSFetchRequest<NSDictionary>
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.returnsDistinctResults = true
        fetchRequest.propertiesToFetch = [#keyPath(StoreApp._category)]
        fetchRequest.predicate = StoreApp.visibleAppsPredicate
        
        do
        {
            let dictionaries = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
            
            // Keep nil values
            let categories = dictionaries.map { $0[#keyPath(StoreApp._category)] as? String? ?? nil }.map { rawCategory -> StoreCategory in
                guard let rawCategory else { return .other }
                return StoreCategory(rawValue: rawCategory) ?? .other
            }
            
            var sortedCategories = Set(categories).sorted(by: { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending })
            if let otherIndex = sortedCategories.firstIndex(of: .other)
            {
                // Ensure "Other" is always last
                sortedCategories.move(fromOffsets: [otherIndex], toOffset: sortedCategories.count)
            }
            
            let actions = sortedCategories.map { category in
                let state: UIAction.State = (category == self.category) ? .on : .off
                let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(category.tintColor, renderingMode: .alwaysOriginal)
                return UIAction(title: category.localizedName, image: image, state: state) { _ in
                    handler(category)
                }
            }
            
            return actions
        }
        catch
        {
            debugLog("Failed to fetch categories. \(error.localizedDescription)")
            
            return []
        }
    }
    
    func prepareAppSorting()
    {
        // focusmaxxing hub: two apps need no sort menu. what the bar carries instead is the two
        // things the old "My apps" tab was the only home for.
        if self.isFocusmaxxingList
        {
            self.prepareFocusmaxxingBar()
            return
        }

        if self.preferredAppSorting == .default && self.source == nil
        {
            // Only allow `default` sorting if source is non-nil.
            // Otherwise, fall back to `lastUpdated` sorting.
            self.preferredAppSorting = .lastUpdated
            
            // Don't update UserDefaults unless explicitly changed by user.
            // UserDefaults.standard.preferredAppSorting = .lastUpdated
        }
        
        let children = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            
            var sortingOptions = AppSorting.allCases
            if self.source == nil
            {
                // Only allow `default` sorting when source is non-nil.
                sortingOptions = sortingOptions.filter { $0 != .default }
            }
            
            let actions = sortingOptions.map { sorting in
                let state: UIMenuElement.State = (sorting == self.preferredAppSorting) ? .on : .off
                let action = UIAction(title: sorting.localizedName, image: nil, state: state) { action in
                    self.preferredAppSorting = sorting
                    UserDefaults.standard.preferredAppSorting = sorting // Update separately to save change.
                    
                    self.updateDataSource()
                }
                
                return action
            }
            
            completion(actions)
        }
        
        let sortMenu = UIMenu(title: NSLocalizedString("Sort by…", comment: ""), options: [.singleSelection], children: [children])
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down")
        
        let sortButton = UIBarButtonItem(title: NSLocalizedString("Sort by…", comment: ""), image: sortIcon, primaryAction: nil, menu: sortMenu)
        self.sortButton = sortButton
        
        self.navigationItem.rightBarButtonItems = [sortButton]
    }
}

private extension BrowseViewController
{
    @IBAction func performAppAction(_ sender: PillButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let app = self.dataSource.item(at: indexPath)

        // focusmaxxing hub: the hub's own tile has no Open - its button is hidden unless there is
        // an update - so a stray tap must do nothing rather than fall through to install, which
        // would put the hub on top of itself for no reason.
        if app.bundleIdentifier == StoreApp.altstoreAppID, !(app.installedApp?.hasUpdate ?? false) { return }

        // if let installedApp = app.installedApp, !installedApp.isUpdateAvailable
        if let installedApp = app.installedApp, !installedApp.hasUpdate
        {
            self.open(installedApp)
        }
        else
        {
            self.install(app, at: indexPath) { progress in
                sender.progress = progress
            }
        }
    }
    
    func install(_ app: StoreApp, at indexPath: IndexPath, progressUpdateHandler: @escaping (Progress) -> Void)
    {
        let previousProgress = AppManager.shared.installationProgress(for: app)
        guard previousProgress == nil else {
            previousProgress?.cancel()
            return
        }
        
        Task(priority: .userInitiated) { @MainActor in
            // if let installedApp = app.installedApp, installedApp.isUpdateAvailable
            if let installedApp = app.installedApp, installedApp.hasUpdate
            {
                let progress = AppManager.shared.update(installedApp, presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(progress)
            }
            else
            {
                let group = await AppManager.shared.installAsync(app, presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(group.progress)
            }
        }
        
        nonisolated func finish(_ result: Result<InstalledApp, Error>)
        {
            debugLog("BrowseViewController.finish invoked with result: \(result) for \(app.bundleIdentifier)")
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error) where error is CancellationError: break // Ignore
                case .failure(let error):
                    let toastView = ToastView(error: error, opensLog: true)
                    toastView.show(in: self)
                    
                case .success: debugLog("Installed app: \(app.bundleIdentifier)")
                }
                
                UIView.performWithoutAnimation {
                    if let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: app)
                    {
                        debugLog("BrowseViewController.finish: reloading item at \(indexPath)")
                        self.collectionView.reloadItems(at: [indexPath])
                    }
                    else
                    {
                        debugLog("BrowseViewController.finish: reloading section")
                        self.collectionView.reloadSections(IndexSet(integer: indexPath.section))
                    }
                }
            }
        }
    }
    
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL)
    }
}

extension BrowseViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let item = self.dataSource.item(at: indexPath)
        let itemID = item.globallyUniqueID ?? item.bundleIdentifier

        if let previousSize = self.cachedItemSizes[itemID]
        {
            return previousSize
        }
        
        self.dataSource.cellConfigurationHandler(self.prototypeCell, item, indexPath)
        
        let insets = (self.view.layoutMargins.left + self.view.layoutMargins.right)

        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionView.bounds.width - insets)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }

        // Manually update cell width & layout so we can accurately calculate screenshot sizes.
        self.prototypeCell.frame.size.width = widthConstraint.constant
        self.prototypeCell.layoutIfNeeded()
        
        let itemSize = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.cachedItemSizes[itemID] = itemSize
        return itemSize
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let app = self.dataSource.item(at: indexPath)
        let appViewController = AppViewController.makeAppViewController(app: app)
        
        // Fall back to presentingViewController.navigationController in case we're being used for search results.
        let navigationController = self.navigationController ?? self.presentingViewController?.navigationController
        navigationController?.pushViewController(appViewController, animated: true)
    }
}

extension BrowseViewController: UIViewControllerPreviewingDelegate
{
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let indexPath = self.collectionView.indexPathForItem(at: location),
            let cell = self.collectionView.cellForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = cell.frame
        
        let app = self.dataSource.item(at: indexPath)
        
        let appViewController = AppViewController.makeAppViewController(app: app)
        return appViewController
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}


// MARK: - focusmaxxing: what the "My apps" tab used to be the only home for
//
// Until 2026-09-08 the hub had two tabs of apps: this one, and "My apps". They showed the same two
// apps and the owner could not tell them apart. My apps had three things this one did not - how
// many days each app has left before it stops opening, the button that renews them all, and the
// screen where an app can be turned off, removed or backed up - so those three came here, and that
// tab went. The screen itself was not rewritten: it is one push away (FMXInstalledApps).
//
// The countdown is the point of all this. It is the only warning a customer gets that a block is
// about to stop working, and the reminder notification asks them to do something about it, so it
// has to be on the tab they open rather than one tab further in.

extension BrowseViewController
{
    /// the two buttons the Apps tab carries: renew everything, and the list of what is installed.
    func prepareFocusmaxxingBar()
    {
        #if !os(tvOS)
        let refresh = UIBarButtonItem(title: NSLocalizedString("Refresh all", comment: ""),
                                      style: .plain, target: self,
                                      action: #selector(BrowseViewController.fmxRefreshAll(_:)))
        refresh.setTitleTextAttributes([.font: FMXFont.of(15, .bold)], for: .normal)
        refresh.setTitleTextAttributes([.font: FMXFont.of(15, .bold)], for: .highlighted)
        refresh.setTitleTextAttributes([.font: FMXFont.of(15, .bold)], for: .disabled)
        self.navigationItem.rightBarButtonItem = refresh

        let installed = UIBarButtonItem(image: UIImage(systemName: "square.stack"),
                                        style: .plain, target: self,
                                        action: #selector(BrowseViewController.fmxShowInstalled(_:)))
        installed.accessibilityLabel = FMXInstalledApps.title
        self.navigationItem.leftBarButtonItem = installed
        #endif
    }

    @objc func fmxShowInstalled(_ sender: Any)
    {
        FMXInstalledApps.show(from: self)
    }

    /// renew every installed app, the way the old tab's header button did.
    @objc func fmxRefreshAll(_ sender: UIBarButtonItem)
    {
        let installedApps = InstalledApp.fetchAppsForRefreshingAll(in: DatabaseManager.shared.viewContext)
        guard !installedApps.isEmpty else {
            ToastView(error: OperationError.noInstalledApps).show(in: self)
            return
        }

        sender.isEnabled = false

        let group = AppManager.shared.refresh(installedApps, presentingViewController: self, group: nil)
        group.completionHandler = { [weak self] results in
            DispatchQueue.main.async {
                sender.isEnabled = true
                guard let self else { return }

                // a renewal moves every expiry a week out, so the countdowns on screen are stale
                self.fmxRefreshDaysLeft()

                let failures = results.compactMapValues { result -> Error? in
                    switch result
                    {
                    case .failure(let error) where error is CancellationError: return nil
                    case .failure(let error): return error
                    case .success: return nil
                    }
                }

                guard !failures.isEmpty else { return }

                if let failure = failures.first, results.count == 1
                {
                    ToastView(error: failure.value).show(in: self)
                    return
                }

                let text = (failures.count == 1)
                    ? NSLocalizedString("Failed to refresh 1 app.", comment: "")
                    : String(format: NSLocalizedString("Failed to refresh %@ apps.", comment: ""), NSNumber(value: failures.count))

                let error = failures.first?.value as NSError?
                let detail = error?.localizedFailure ?? error?.localizedFailureReason ?? error?.localizedDescription

                let toastView = ToastView(text: text, detailText: detail, opensLog: true)
                toastView.preferredDuration = 4.0
                toastView.show(in: self)
            }
        }
    }

    /// how long this app has left, written above its button.
    ///
    /// the button itself is deliberately left alone. on the old tab the countdown WAS the button,
    /// which is why tapping "6 DAYS" renewed the app; here the button stays Install / Open / Update
    /// and the countdown is the small line over it, so nothing a customer taps changed meaning.
    /// the colours are the four the product already uses for this (they are what
    /// `Refresh*.colorset` were pointed at during the design pass: volt, ember, ember deep, danger).
    func fmxShowDaysLeft(on cell: AppCardCollectionViewCell, for app: StoreApp)
    {
        guard let label = cell.bannerView.buttonLabel else { return }

        // the hub's own tile hides its button unless there is an update, and this label is
        // positioned against that button - drawn over a collapsed one it is cut in half by the edge
        // of the card. the hub is also the one app this countdown is not needed for: it renews
        // itself, and the store it is forked from books its own warnings about it, which is why
        // FMXReminder leaves it out too.
        guard self.isFocusmaxxingList,
              !cell.bannerView.button.isHidden,
              let installedApp = app.installedApp, installedApp.isActive
        else {
            label.isHidden = true
            return
        }

        label.font = FMXFont.of(10, .heavy)
        label.isHidden = false

        if installedApp.certificateStatus == .revoked
        {
            label.text = NSLocalizedString("Expired", comment: "").uppercased()
            label.textColor = .refreshRed
            return
        }

        let now = Date()
        guard now < installedApp.expirationDate, installedApp.certificateStatus != .expired else {
            label.text = NSLocalizedString("Expired", comment: "").uppercased()
            label.textColor = .refreshRed
            return
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.maximumUnitCount = 1

        label.text = (formatter.string(from: now, to: installedApp.expirationDate) ?? "").uppercased()

        let days = Calendar.current.dateComponents([.day], from: now, to: installedApp.expirationDate).day ?? 0
        switch days
        {
        case 6...: label.textColor = .refreshGreen
        case 4...5: label.textColor = .refreshYellow
        case 2...3: label.textColor = .refreshOrange
        default: label.textColor = .refreshRed
        }
    }

    /// redraw only the countdowns, leaving every button and every progress bar where it is.
    func fmxRefreshDaysLeft()
    {
        guard self.isFocusmaxxingList else { return }

        for cell in self.collectionView.visibleCells
        {
            guard let cell = cell as? AppCardCollectionViewCell,
                  let indexPath = self.collectionView.indexPath(for: cell)
            else { continue }

            self.fmxShowDaysLeft(on: cell, for: self.dataSource.item(at: indexPath))
        }
    }
}
