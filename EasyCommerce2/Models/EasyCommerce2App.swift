//
//  EasyCommerce2App.swift
//  EasyCommerce2
//
//  Created by Gabriele Fiore on 08/12/24.
//

import SwiftUI

@main
struct EasyCommerce2App: App {
    @StateObject private var libraryManager = PhotoLibraryManager()
    init() {
            // Customize selected and unselected tab bar items
        UITabBar.appearance().tintColor = UIColor(red: 137 / 255, green: 87 / 255, blue: 244 / 255, alpha: 1.0) // Custom active color
            UITabBar.appearance().unselectedItemTintColor = UIColor.gray // Optional: Set unselected color
        }
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .environmentObject(libraryManager) // Inject the environment object here
         }
     }
 }
