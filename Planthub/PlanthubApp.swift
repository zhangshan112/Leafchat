//
//  PlanthubApp.swift
//  Planthub
//
//  Created by LXL on 2026/6/5.
//

import SwiftUI

@main
struct PlanthubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
