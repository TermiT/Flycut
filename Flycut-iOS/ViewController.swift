//
//  ViewController.swift
//  Flycut-iOS
//
//  Created by Mark Jerde on 7/12/17.
//
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, FlycutStoreDelegate, FlycutOperatorDelegate {

	let flycut:FlycutOperator = FlycutOperator()
	var activeUpdates:Int = 0
	var tableView:UITableView!
	var currentAnimation = UITableViewRowAnimation.none
	var pbCount:Int = -1
	var rememberedSyncSettings:Bool = false
	var rememberedSyncClippings:Bool = false

	let pasteboardInteractionQueue = DispatchQueue(label: "com.Flycut.pasteboardInteractionQueue")
	let alertHandlingSemaphore = DispatchSemaphore(value: 0)
	let defaultsChangeHandlingQueue = DispatchQueue(label: "com.Flycut.defaultsChangeHandlingQueue")

	let isURLDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

	// Some buttons we will reuse.
	var deleteButton:MGSwipeButton? = nil
	var openURLButton:MGSwipeButton? = nil

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.

		// Uncomment the following line to load the demo state for screenshots.
		//UserDefaults.standard.set(NSNumber(value: true), forKey: "demoForAppStoreScreenshots")
		// Use this command to get screenshots:
		// while true; do xcrun simctl io booted screenshot;sleep 1;done

		if ( UserDefaults.standard.bool(forKey: "demoForAppStoreScreenshots") )
		{
			// Ensure we will not load or save clippings in demo mode.
			let savePref = UserDefaults.standard.integer(forKey: "savePreference")
			if ( 0 < savePref )
			{
				UserDefaults.standard.set(0, forKey: "savePreference")
			}
		}

		tableView = self.view.subviews.first as! UITableView
		tableView.delegate = self
		tableView.dataSource = self

		tableView.register(MGSwipeTableCell.self, forCellReuseIdentifier: "FlycutCell")

		deleteButton = MGSwipeButton(title: "Delete", backgroundColor: .red, callback: { (cell) -> Bool in
			let indexPath = self.tableView.indexPath(for: cell)
			if ( nil != indexPath ) {
				let previousAnimation = self.currentAnimation
				self.currentAnimation = UITableViewRowAnimation.left // Use .left to look better with swiping left to delete.
				self.flycut.setStackPositionTo( Int32((indexPath?.row)! ))
				self.flycut.clearItemAtStackPosition()
				self.currentAnimation = previousAnimation
			}

			return true;
		})

		openURLButton = MGSwipeButton(title: "Open", backgroundColor: .blue, callback: { (cell) -> Bool in
			let indexPath = self.tableView.indexPath(for: cell)
			if ( nil != indexPath ) {
				let url = URL(string: self.flycut.clippingString(withCount: Int32((indexPath?.row)!) )! )
				if #available(iOS 10.0, *) {
					UIApplication.shared.open(url!, options: [:], completionHandler: nil)
				} else {
					// Fallback on earlier versions
					UIApplication.shared.openURL(url!)
				}
				self.tableView.reloadRows(at: [indexPath!], with: UITableViewRowAnimation.none)
			}

			return true;
		})

		// Force sync disable for test if needed.
		//UserDefaults.standard.set(NSNumber(value: false), forKey: "syncSettingsViaICloud")
		//UserDefaults.standard.set(NSNumber(value: false), forKey: "syncClippingsViaICloud")
		// Force to ask to enable sync for test if needed.
		//UserDefaults.standard.set(false, forKey: "alreadyAskedToEnableSync")

		// Ensure these are false since there isn't a way to access the saved clippings on iOS as this point.
		UserDefaults.standard.set(NSNumber(value: false), forKey: "saveForgottenClippings")
		UserDefaults.standard.set(NSNumber(value: false), forKey: "saveForgottenFavorites")

		flycut.setClippingsStoreDelegate(self)
		flycut.delegate = self

		flycut.awake(fromNibDisplaying: 10, withDisplayLength: 140, withSave: #selector(savePreferences(toDict:)), forTarget: self) // The 10 isn't used in iOS right now and 140 characters seems to be enough to cover the width of the largest screen.

		NotificationCenter.default.addObserver(self, selector: #selector(self.checkForClippingAddedToClipboard), name: .UIPasteboardChanged, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillTerminate), name: .UIApplicationWillTerminate, object: nil)

		// Check for clipping whenever we become active.
		NotificationCenter.default.addObserver(self, selector: #selector(self.checkForClippingAddedToClipboard), name: .UIApplicationDidBecomeActive, object: nil)
		checkForClippingAddedToClipboard() // Since the first-launch notification will occur before we add observer.

		// Register for notifications for the scenarios in which we should save the engine.
		[ Notification.Name.UIApplicationWillResignActive,
		  Notification.Name.UIApplicationDidEnterBackground,
		  Notification.Name.UIApplicationWillTerminate ]
			.forEach { (notification) in
			NotificationCenter.default.addObserver(self,
			                                       selector: #selector(self.saveEngine),
			                                       name: notification,
			                                       object: nil)
		}

		NotificationCenter.default.addObserver(self, selector: #selector(self.defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)

		if ( UserDefaults.standard.bool(forKey: "demoForAppStoreScreenshots") )
		{
			// Make sure we won't send these change to iCloud.
			UserDefaults.standard.set(NSNumber(value: false), forKey: "syncSettingsViaICloud")
			UserDefaults.standard.set(NSNumber(value: false), forKey: "syncClippingsViaICloud")
			self.flycut.registerOrDeregisterICloudSync()
			NotificationCenter.default.removeObserver(self)

			// Load sample content, reverse order.
			self.flycut.addClipping("https://www.apple.com", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("App Store is a digital distribution platform, developed and maintained by Apple Inc., for mobile apps on its iOS operating system.", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("https://itunesconnect.apple.com/", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("The party is at 123 Main St. 6 PM. Please bring some chips to share.", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("You are going to love this new design I found. It takes half the effort and resonates with today's hottest trends. With our throughput up we can now keep up with demand.", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("http://www.makeuseof.com/tag/5-best-mac-clipboard-manager-apps-improve-workflow/", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Swipe left to delete", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Swipe right to open web links", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Tap to copy", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Manage your clippings in iOS", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Flycut has made the leap from macOS to iOS", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
			self.flycut.addClipping("Flycut has made the leap from OS X to iOS", ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)

			// Unset the demo setting.
			UserDefaults.standard.set(NSNumber(value: false), forKey: "demoForAppStoreScreenshots")
		}
	}

	func defaultsChanged() {
		// This seems to be the only way to respond to Settings changes, though it doesn't inform us what changed so we will have to check each to see if they were the one(s).

		// Don't use DispatchQueue.main.async since that will still end up blocking the UI draw until the user responds to what hasn't been drawn yet.
		// Use async on a sequential queue to avoid concurrent response to the same change.  This allows enqueuing of defaultsChanged calls in reponse to changes made within the handling, but using sync causes EXC_BAD_ACCESS in this case.
		defaultsChangeHandlingQueue.async {
			let newRememberNum = Int32(UserDefaults.standard.integer(forKey: "rememberNum"))
			if ( UserDefaults.standard.value(forKey: "rememberNum") is String )
			{
				// Reset the value, since TextField will make it a String and CloudKit sync will object to changing the type.  Check this independent of value change, since the type could be changed without a change in value and we don't want it left around causing confusion.
				UserDefaults.standard.set(newRememberNum, forKey: "rememberNum")
			}
			if ( self.flycut.rememberNum() != newRememberNum ) {
				self.flycut.setRememberNum(newRememberNum, forPrimaryStore: true)
			}

			let syncSettings = UserDefaults.standard.bool(forKey: "syncSettingsViaICloud")
			let syncClippings = UserDefaults.standard.bool(forKey: "syncClippingsViaICloud")
			if ( syncSettings != self.rememberedSyncSettings
				|| syncClippings != self.rememberedSyncClippings )
			{
				self.rememberedSyncSettings = syncSettings
				self.rememberedSyncClippings = syncClippings
				self.flycut.registerOrDeregisterICloudSync()
			}
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		// Ask once to enable Sync.  The syntax below will take the else unless alreadyAnswered is non-nil and true.
		let alreadyAsked = UserDefaults.standard.value(forKey: "alreadyAskedToEnableSync")
		if let answer = alreadyAsked, answer as! Bool
		{
		}
		else
		{
			// Don't use DispatchQueue.main.async since that will still end up blocking the UI draw until the user responds to what hasn't been drawn yet.  Just create a queue to get us away from main, since this is a one-time code path.
			DispatchQueue(label: "com.Flycut.alertHandlingQueue", qos: .userInitiated ).async {
				let selection = self.alert(withMessageText: "iCloud Sync", informationText: "Would you like to enable Flycut's iCloud Sync for Settings and Clippings?", buttonsTexts: ["Yes", "No"])

				let response = (selection == "Yes");
				UserDefaults.standard.set(NSNumber(value: response), forKey: "syncSettingsViaICloud")
				UserDefaults.standard.set(NSNumber(value: response), forKey: "syncClippingsViaICloud")
				UserDefaults.standard.set(true, forKey: "alreadyAskedToEnableSync")
				self.flycut.registerOrDeregisterICloudSync()
			}
		}

		// This is a suitable place to prepare to possible eventual display of preferences, resetting values that should reset before each display of preferences.
		flycut.willShowPreferences()
	}

	func savePreferences(toDict: NSMutableDictionary)
	{
	}

	func beginUpdates()
	{
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { beginUpdates() }
			return
		}

		print("Begin updates")
		print("Num rows: \(tableView.dataSource?.tableView(tableView, numberOfRowsInSection: 0))")
		if ( 0 == activeUpdates )
		{
			tableView.beginUpdates()
		}
		activeUpdates += 1
	}

	func endUpdates()
	{
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { endUpdates() }
			return
		}

		print("End updates");
		activeUpdates -= 1;
		if ( 0 == activeUpdates )
		{
			tableView.endUpdates()
		}
	}

	func insertClipping(at index: Int32) {
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { insertClipping(at: index) }
			return
		}
		print("Insert row \(index)")
		tableView.insertRows(at: [IndexPath(row: Int(index), section: 0)], with: currentAnimation) // We will override the animation for now, because we are the ViewController and should guide the UX.
	}

	func deleteClipping(at index: Int32) {
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { deleteClipping(at: index) }
			return
		}
		print("Delete row \(index)")
		tableView.deleteRows(at: [IndexPath(row: Int(index), section: 0)], with: currentAnimation) // We will override the animation for now, because we are the ViewController and should guide the UX.
	}

	func reloadClipping(at index: Int32) {
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { reloadClipping(at: index) }
			return
		}
		print("Reloading row \(index)")
		tableView.reloadRows(at: [IndexPath(row: Int(index), section: 0)], with: currentAnimation) // We will override the animation for now, because we are the ViewController and should guide the UX.
	}

	func moveClipping(at index: Int32, to newIndex: Int32) {
		if ( !Thread.isMainThread )
		{
			DispatchQueue.main.sync { moveClipping(at: index, to: newIndex) }
			return
		}
		print("Moving row \(index) to \(newIndex)")
		tableView.moveRow(at: IndexPath(row: Int(index), section: 0), to: IndexPath(row: Int(newIndex), section: 0))
	}

	func alert(withMessageText message: String!, informationText information: String!, buttonsTexts buttons: [Any]!) -> String! {
		// Don't use DispatchQueue.main.async since that will still end up blocking the UI draw until the user responds to what hasn't been drawn yet.  This isn't a great check, as it is OS-version-limited and results in a EXC_BAD_INSTRUCTION if it fails, but is good enough for development / test.
		if #available(iOS 10.0, *) {
			__dispatch_assert_queue_not(DispatchQueue.main)
		}

		let alertController = UIAlertController(title: message, message: information, preferredStyle: .alert)
		var selection:String? = nil
		for option in buttons
		{
			alertController.addAction(UIAlertAction(title: option as? String, style: .default) { action in
				selection = action.title
				self.alertHandlingSemaphore.signal()
			})
		}

		if var topController = UIApplication.shared.keyWindow?.rootViewController {
			while let presentedViewController = topController.presentedViewController {
				topController = presentedViewController
			}

			// topController should now be your topmost view controller

			// Transform the asynchronous UIAlertController into a synchronous alert by waiting, after presenting, on a semaphore that is initialized to zero and only signaled in the selection handler.

			DispatchQueue.main.async {
				topController.present(alertController, animated: true)
			}
			alertHandlingSemaphore.wait() // To wait for queue to resume.
		}

		return selection
	}

	func checkForClippingAddedToClipboard()
	{
		pasteboardInteractionQueue.async {
			// This is a suitable place to prepare to possible eventual display of preferences, resetting values that should reset before each display of preferences.
			self.flycut.willShowPreferences()

			if ( UIPasteboard.general.changeCount != self.pbCount )
			{
				self.pbCount = UIPasteboard.general.changeCount;

				if ( UIPasteboard.general.types.contains("public.utf8-plain-text") )
				{
					let pasteboard = UIPasteboard.general.value(forPasteboardType: "public.utf8-plain-text")
					self.flycut.addClipping(pasteboard as! String!, ofType: "public.utf8-plain-text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
				}
				else if ( UIPasteboard.general.types.contains("public.text") )
				{
					let pasteboard = UIPasteboard.general.value(forPasteboardType: "public.text")
					self.flycut.addClipping(pasteboard as! String!, ofType: "public.text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)
				}
			}
		}
	}

	func applicationWillTerminate()
	{
		saveEngine()
	}

	func saveEngine()
	{
		flycut.saveEngine()
	}

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		saveEngine()
		// Dispose of any resources that can be recreated.
	}

	func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return Int(flycut.jcListCount())
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item: MGSwipeTableCell = tableView.dequeueReusableCell(withIdentifier: "FlycutCell", for: indexPath) as! MGSwipeTableCell

		item.textLabel?.text = flycut.previousDisplayStrings(indexPath.row + 1, containing: nil).last as! String?

		//configure left buttons
		var removeAll:Bool = true
		if let content = flycut.clippingString(withCount: Int32(indexPath.row) )
		{
			// Detect if something is a URL before passing it to canOpenURL because on iOS 9 and later, if building with an earlier SDK,  there is a limit of 50 distinct URL schemes before canOpenURL will just return false.  This limit is theorized to prevent apps from detecting what other apps are installed.  The limit should be okay, assuming any user encounters fewer than 50 URL schemes, since those that the user actually uses will be allowed through before reaching the limit.  For building with an iOS 9 or later SDK a whitelist of schemes in the Info.plist will be used, but filtering before calling canOpenURL decreases the volume of log messages.

			// NSTextCheckingResult.CheckingType.link.rawValue blocks things like single words that URL() would let in
			// URL() blocks things like paragraphs of text containing a URL that NSTextCheckingResult.CheckingType.link.rawValue would let in

			let matches = isURLDetector?.matches(in: content, options: .reportCompletion, range: NSMakeRange(0, content.characters.count))
			if let matchesCount = matches?.count
			{
				if matchesCount > 0
				{
					if let url = URL(string: content)
					{
						if UIApplication.shared.canOpenURL( url ) {
							if(!item.leftButtons.contains(openURLButton!))
							{
								item.leftButtons.append(openURLButton!)
								item.leftSwipeSettings.transition = .border
								item.leftExpansion.buttonIndex=0
								removeAll = false
							}
						}
					}
				}
			}
		}
		if ( removeAll ) {
			item.leftButtons.removeAll()
		}

		//configure right buttons
		if ( 0 == item.rightButtons.count )
		{
			// Setup the right buttons only if they haven't been before.
			item.rightButtons.append(deleteButton!)
			item.rightSwipeSettings.transition = .border
			item.rightExpansion.buttonIndex = 0
		}

		return item
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if ( MGSwipeState.none == (tableView.cellForRow(at: indexPath) as! MGSwipeTableCell).swipeState ) {
			tableView.deselectRow(at: indexPath, animated: true) // deselect before getPaste since getPaste may reorder the list
			let content = flycut.getPasteFrom(Int32(indexPath.row))
			print("Select: \(indexPath.row) \(content) OK")

			pasteboardInteractionQueue.async {
				// Capture value before setting the pastboard for reasons noted below.
				self.pbCount = UIPasteboard.general.changeCount

				// This call will clear all other content types and appears to immediately increment the changeCount.
				UIPasteboard.general.setValue(content as Any, forPasteboardType: "public.utf8-plain-text")

				// Apple documents that "UIPasteboard waits until the end of the current event loop before incrementing the change count", but this doesn't seem to be the case for the above call.  Handle both scenarios by doing a simple increment if unchanged and an update-to-match if changed.
				if ( UIPasteboard.general.changeCount == self.pbCount )
				{
					self.pbCount += 1
				}
				else
				{
					self.pbCount = UIPasteboard.general.changeCount
				}
			}
		}
	}
}

