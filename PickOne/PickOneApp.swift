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
    private let container: AppContainer?

    init() {
        container = AppConfiguration.isUnitTesting ? nil : AppContainer()
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                AppRootView(
                    container: container,
                    profileModel: container.viewerProfileViewModel
                )
            }
        }
    }
}
