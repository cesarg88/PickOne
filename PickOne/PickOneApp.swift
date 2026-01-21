//
//  PickOneApp.swift
//  PickOne
//
//  Created by César González on 19/1/26.
//

import SwiftUI

@main
struct PickOneApp: App {
    private let container = AppContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
