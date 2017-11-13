//
//  SettingsView.swift
//  Flycut
//
//  Created by Mark Jerde on 10/24/17.
//
//

import Foundation

class SettingsViewController: IASKAppSettingsViewController {
	required init?(coder aDecoder: NSCoder) {
		super.init(style: .grouped)
		commonInitContent()
	}

	// - (id)initWithStyle:(UITableViewStyle)style {
	required override init(style:UITableViewStyle) {
		super.init(style: style)
		commonInitContent()
	}

	func commonInitContent() {
		super.showCreditsFooter = false

		let fileRoot = Bundle.main.path(forResource: "acknowledgements", ofType: "txt")
		let contents = try? String.init(contentsOfFile: fileRoot!, encoding: String.Encoding.utf8)
		UserDefaults.standard.set(contents, forKey: "acknowledgementsText")

		let data = MJCloudKitUserDefaultsSync.diagnosticData()
		UserDefaults.standard.set(data, forKey: "diagnosticsText")
	}
}
