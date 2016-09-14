//
//  NewsTableViewController.swift
//  Daily Koszalin
//
//  Created by Adrian on 19.08.2016.
//  Copyright © 2016 Adrian Kubała. All rights reserved.
//

import UIKit
import FeedKit
import AlamofireImage

class NewsTableViewController: UITableViewController {

    var news: [News] = []
    var filteredNews: [News] = []
    let rssURLs = ["gk24" : NSURL(string: "http://www.gk24.pl/rss/gloskoszalinski.xml"),
                   "radiokoszalin" : NSURL(string: "http://www.radio.koszalin.pl/Content/rss/region.xml"),
                   "naszemiasto" : NSURL(string: "http://koszalin.naszemiasto.pl/rss/artykuly/1.xml"),
                   "koszalin" : NSURL(string: "http://www.koszalin.pl/pl/rss.xml")]
    
    let searchController = UISearchController(searchResultsController: nil)
    
    static var arrayFilePath: String? {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first
        return url?.URLByAppendingPathComponent("news").path
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        enableSelfSizingCells()

        assignLoadedNews()
        
        setupRefreshControl()
        setupSearchController()
    }
    
    func enableSelfSizingCells() {
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 80
    }
    
    func assignLoadedNews() {
        if let savedNews = loadNewsFromDisk() {
            news = savedNews
        }
    }
    
    func loadNewsFromDisk() -> [News]? {
        guard let filePath = NewsTableViewController.arrayFilePath else {
            return nil
        }
        
        return NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [News]
    }
    
    func setupRefreshControl() {
        refreshControl?.addTarget(self, action: #selector(NewsTableViewController.handleRefresh(_:)), forControlEvents: UIControlEvents.ValueChanged)
    }
    
    func handleRefresh(refreshControl: UIRefreshControl) {
        parseContentFromURL(rssURLs)
        
        refreshControl.endRefreshing()
    }
    
    func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        
        setupSearchBar()
    }
    
    func setupSearchBar() {
        let searchBar = searchController.searchBar
        tableView.tableHeaderView = searchBar
        searchBar.autocapitalizationType = .None
        searchBar.placeholder = "Wyszukaj"
        searchBar.scopeButtonTitles = ["Wszystkie", "Do 3 dni", "Do 5 dni"]
        searchBar.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        parseContentFromURL(rssURLs)
    }
    
    func parseContentFromURL(urls: [String: NSURL?]) {
        for url in urls.values {
            guard ConnectionManager.sharedInstance.isConnectedToNetwork() else {
                ConnectionManager.sharedInstance.showAlertIfNeeded(onViewController: self)
                
                break
            }
            
            guard let feedUrl = url else {
                continue
            }
            
            FeedParser(URL: feedUrl)?.parse({ (result) in
                switch result {
                case .RSS(let rssFeed):
                    dataLoop: for item in rssFeed.items! {
                        
                        for article in self.news {
                            guard article.title != item.title else {
                                continue dataLoop
                            }
                            
                        }
                        
                        let obj = News(source: rssFeed.link, title: item.title, link: item.link, pubDate: item.pubDate, favIcon: nil)
                        
                        if let feedLink = rssFeed.link {
                            obj.setupFavIcon(feedLink)
                        }
                
                        self.news.append(obj)
                    }
                case .Atom(let atomFeed):
                    dataLoop: for item in atomFeed.entries! {
                        
                        for article in self.news {
                            guard article.title != item.title else {
                                continue dataLoop
                            }
                            
                        }
                        
                        let feedSource = atomFeed.links?.first?.attributes?.href
                        let itemSource = item.links?.first?.attributes?.href
                        
                        let obj = News(source: feedSource, title: item.title, link: itemSource, pubDate: item.updated, favIcon: nil)
                        if let link = feedSource {
                            obj.setupFavIcon(link)
                        }
                        
                        self.news.append(obj)
                    }
                case .Failure(let error):
                    print(error.localizedDescription)
                }
            })
        }
        sortAndReloadData()
    }
    
    private func sortAndReloadData() {
        news.sortInPlace({ $0.pubDate?.compare($1.pubDate!) == NSComparisonResult.OrderedDescending })
        tableView.reloadData()
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchIsActive() {
            return filteredNews.count
        }
        
        return news.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("newsCell")
        
        guard let newsCell = cell as? TableNewsCell else {
            return UITableViewCell()
        }
        
        let currentNews = chooseData(indexPath.row)
        
        let isFavIcon = newsCell.setupWithData(currentNews)
        
        if isFavIcon {
            saveNewsToDisk()
        }
        
        return newsCell
    }
    
    func chooseData(row: Int) -> News {
        if searchIsActive() {
            return filteredNews[row]
        }
        
        return news[row]
    }
    
    func saveNewsToDisk() {
        guard let filePath = NewsTableViewController.arrayFilePath else {
            return
        }
        
        NSKeyedArchiver.archiveRootObject(news, toFile: filePath)
    }
    
    func searchIsActive() -> Bool {
        if searchController.active {
            return true
        }
        return false
    }
    
    override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        let selectedCell = tableView.cellForRowAtIndexPath(indexPath)
        let isAlreadySelected = selectedCell?.selected
        
        if isAlreadySelected == true {
            return nil
        } else {
            return indexPath
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let selectedNews = chooseData(indexPath.row)
        
        let link = selectedNews.link
        
        let newsVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("idNewsViewController") as? NewsViewController
        
        guard let url = link, let webViewVC = newsVC else {
            return
        }
        
        webViewVC.newsURL = NSURL(string: url)
        
        let mySplitVC = splitViewController as? EmbeddedSplitViewController
        mySplitVC?.unCollapseSecondaryVCOntoPrimary()
        
        showDetailViewController(webViewVC, sender: self)
    }
    
    func filterContentForSearchText(searchText: String, scope: String) {
        filteredNews = news.filter { news in
            guard let newsTitle = news.title, let newsDate = news.pubDate else {
                return false
            }
            
            let currentDate = NSDate()
            let difference = currentDate.daysBetweenDates(newsDate)
            
            let dateMatch = doesMatchByDaysDifference(difference, within: scope)
            
            let filterMatch = (scope == "Wszystkie") || dateMatch
            
            if searchText != "" {
                return filterMatch && newsTitle.lowercaseString.containsString(searchText.lowercaseString)
            } else {
                return filterMatch
            }
        }
        tableView.reloadData()
    }
    
    func doesMatchByDaysDifference(days: Int, within scope: String) -> Bool {
        var doesMatch = false
        switch scope {
        case "Do 3 dni":
            if days < 3 {
                doesMatch = true
            }
        case "Do 5 dni":
            if days < 5 {
                doesMatch = true
            }
        default:
            doesMatch = false
        }
        return doesMatch
    }
}
