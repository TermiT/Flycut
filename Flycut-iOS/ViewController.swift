//
//  ViewController.swift
//  Flycut-iOS
//
//  Created by Mark Jerde on 7/12/17.
//
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

	let flycut:FlycutOperator = FlycutOperator()
	var adjustQuantity:Int = 0
	var tableView:UITableView!

	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view, typically from a nib.

		tableView = self.view.subviews.first as! UITableView
		tableView.delegate = self
		tableView.dataSource = self

		flycut.awake(fromNibDisplaying: 10, withDisplayLength: 140, withSave: #selector(savePreferences(toDict:)), forTarget: self) // The 10 isn't used in iOS right now and 140 characters seems to be enough to cover the width of the largest screen.

		NotificationCenter.default.addObserver(self, selector: #selector(self.checkForClippingAddedToClipboard), name: .UIPasteboardChanged, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(self.applicationWillTerminate), name: .UIApplicationWillTerminate, object: nil)
	}

	func savePreferences(toDict: NSMutableDictionary)
	{
	}

	func checkForClippingAddedToClipboard()
	{
		let pasteboard = UIPasteboard.general.string
		if ( nil != pasteboard )
		{

			let startCount = Int(flycut.jcListCount())
			let previousIndex = flycut.index(ofClipping: pasteboard, ofType: "public.utf8-plain-text", fromApp: "iOS", withAppBundleURL: "iOS")
			let added = flycut.addClipping(pasteboard, ofType: "public.utf8-plain-text", fromApp: "iOS", withAppBundleURL: "iOS", target: nil, clippingAddedSelector: nil)

			if ( added )
			{
				var reAdjustQuantity = 0
				var deleteIndex = -1
				if( -1 < previousIndex )
				{
					deleteIndex = Int(previousIndex)
				}
				else if(startCount == Int(flycut.jcListCount()))
				{
					deleteIndex = startCount - 1
				}

				tableView.beginUpdates()
				if ( deleteIndex >= 0 )
				{
					adjustQuantity -= 1
					reAdjustQuantity = 1
					tableView.deleteRows(at: [IndexPath(row: deleteIndex, section: 0)], with: .none)
				}
				adjustQuantity += reAdjustQuantity
				tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .none)
				tableView.endUpdates()
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
		return Int(flycut.jcListCount()) + adjustQuantity
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		//let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "UITableViewCell", for: indexPath)

		let item = MGSwipeTableCell();
		item.textLabel?.text = flycut.previousDisplayStrings(indexPath.row + 1, containing: nil).last as! String?
		let content = flycut.clippingString(withCount: Int32(indexPath.row) )

		//configure left buttons
		if let url = URL(string: content!) {
			if (content?.lowercased().hasPrefix("http"))! {
				item.leftButtons = [MGSwipeButton(title: "Open", backgroundColor: .blue, callback: { (cell) -> Bool in
					let indexPath = tableView.indexPath(for: cell)
					if ( nil != indexPath ) {
						UIApplication.shared.open(url, options: [:], completionHandler: nil)
						tableView.reloadRows(at: [indexPath!], with: UITableViewRowAnimation.none)
					}

					return true;
				})]
				item.leftSwipeSettings.transition = .border
				item.leftExpansion.buttonIndex=0
			}
		}

		//configure right buttons
		item.rightButtons = [MGSwipeButton(title: "Delete", backgroundColor: .red, callback: { (cell) -> Bool in
			let indexPath = tableView.indexPath(for: cell)
			if ( nil != indexPath ) {
				self.flycut.setStackPositionTo( Int32((indexPath?.row)! ))
				self.flycut.clearItemAtStackPosition()
				tableView.beginUpdates()
				tableView.deleteRows(at: [indexPath!], with: .left) // Use .left to look better with swiping left to delete.
				tableView.endUpdates()
			}

			return true;
		})]
		item.rightSwipeSettings.transition = .border
		item.rightExpansion.buttonIndex = 0

		return item
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if ( MGSwipeState.none == (tableView.cellForRow(at: indexPath) as! MGSwipeTableCell).swipeState ) {
			let content = flycut.clippingString(withCount: Int32(indexPath.row) )
			print("Select: \(indexPath.row) \(content) OK")
			tableView.deselectRow(at: indexPath, animated: true)
			UIPasteboard.general.string = content
		}
	}
}

