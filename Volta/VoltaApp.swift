//
//  VoltaApp.swift
//  Volta
//
//  Created by Satori Tech 341 on 09/10/26.
//

import SwiftUI

@main
struct VoltaApp: App {
    @State private var store = BoardStore()

    var body: some Scene {
        WindowGroup {
            ContentView2(store: store)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 820)
        #endif
    }
}
