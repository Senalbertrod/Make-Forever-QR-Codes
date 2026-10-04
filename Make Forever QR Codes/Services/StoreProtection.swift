//
//  StoreProtection.swift
//  Make Forever QR Codes
//
//  Saved codes (including Wi-Fi passwords) are locked by the iPhone's
//  encryption whenever the phone is locked. "Unless open" lets the app
//  finish saving if you lock the phone while it's running.
//

import Foundation

enum StoreProtection {
    static func apply() {
        let fm = FileManager.default
        let folder = URL.applicationSupportDirectory
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUnlessOpen]
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        // New files made in this folder get the same protection.
        try? fm.setAttributes(attributes, ofItemAtPath: folder.path)
        // The saved-codes files that already exist.
        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where name.hasPrefix("default.store") {
            try? fm.setAttributes(attributes, ofItemAtPath: folder.appending(path: name).path)
        }
    }
}
