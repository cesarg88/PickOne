//
//  PickOneApp.swift
//  PickOne
//
//  Created by César González on 19/1/26.
//

import SwiftUI

@main
@MainActor
struct PickOneApp: App {
    private let container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            MainTabView(container: container)
        }
    }
}
