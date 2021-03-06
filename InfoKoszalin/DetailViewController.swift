//
//  DetailViewController.swift
//  InfoKoszalin
//
//  Created by Adrian on 19.08.2016.
//  Copyright © 2016 Adrian Kubała. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController, UIWebViewDelegate {
  @IBOutlet weak var webview: CustomWebView!
  @IBOutlet weak var toolbar: CustomToolbar!
  @IBOutlet var noNews: UILabel!
  @IBOutlet var webViewIndicator: UIActivityIndicatorView!
  
  var newsButtonitem : UIBarButtonItem?
  var newsURL: URL?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    webview.delegate = self
    
    setupNewsButtonItem()
    setupObserver()
  }
  
  private func setupNewsButtonItem() {
    newsButtonitem = UIBarButtonItem(title: "Aktualności", style: .plain, target: self, action: #selector(DetailViewController.showMasterViewController))
  }
  
  private func setupObserver() {
    NotificationCenter.default.addObserver(forName: .DisplayModeChangeNotification) { (notification) in
      self.splitViewControllerDisplayModeDidChange(notification)
    }
  }
  
  func showMasterViewController() {
    UIView.animate(withDuration: 0.2, delay: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
      self.splitViewController?.preferredDisplayMode = .allVisible
      }, completion: nil)
    insertDispModeBtn()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    guard newsURL != nil else {
      return
    }
    
    noNews.isHidden = true
    toolbar.isHidden = false
    webViewIndicator.startAnimating()
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    
    guard let url = newsURL else {
      return
    }
    
    webview.makeRequest(url)
    webview.setupAppearance()
    
    insertDisplayModeButton()
  }
  
  func splitViewControllerDisplayModeDidChange(_ notification: Notification) {
    let displayModeObject = notification.object as? NSNumber
    let nextDisplayMode = displayModeObject?.intValue
    
    if nextDisplayMode == UISplitViewControllerDisplayMode.primaryHidden.rawValue {
      insertCustomDispModeBtn()
    } else {
      insertDispModeBtn()
    }
    
    guard traitCollection.userInterfaceIdiom == .pad else {
      return
    }
    
    if displayModeIsPrimaryHidden() {
      insertCustomDispModeBtn()
    }
  }
  
  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    
    if previousTraitCollection?.verticalSizeClass == .regular {
      insertDisplayModeButton()
    } else if displayModeIsAllVisible() {
      insertDispModeBtn()
    }
  }
  
  func displayModeIsPrimaryHidden() -> Bool {
    let currentDisplayMode = splitViewController?.displayMode
    return currentDisplayMode == .primaryHidden
  }
  
  func insertDisplayModeButton() {
    if displayModeIsAllVisible() {
      insertDispModeBtn()
    } else {
      insertCustomDispModeBtn()
    }
  }
  
  func displayModeIsAllVisible() -> Bool {
    let currentDisplayMode = splitViewController?.displayMode
    return currentDisplayMode == .allVisible
  }
  
  func insertDispModeBtn() {
    toolbar.removeFirstItem()
    
    if toolbar.itemsCountIsLessThanTwo(), let splitVC = splitViewController {
      toolbar.insertItem(splitVC.displayModeButtonItem, at: 0)
    }
  }
  
  func insertCustomDispModeBtn() {
    toolbar.removeFirstItem()
    
    if toolbar.itemsCountIsLessThanTwo(), let barBtn = newsButtonitem {
      toolbar.insertItem(barBtn, at: 0)
    }
  }
  
  // MARK: UIWebViewDelegate
  
  func webViewDidFinishLoad(_ webView: UIWebView) {
    webViewIndicator.stopAnimating()
  }
  
  func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
    _ = ConnectionManager.sharedInstance.showAlertIfNeeded(onViewController: self)
    
    webViewIndicator.stopAnimating()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}
