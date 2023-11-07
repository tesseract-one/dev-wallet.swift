//
//  ContentView.swift
//  Developer Wallet
//
//  Created by Daniel Leping on 23/01/2023.
//

import SwiftUI

struct ContentView: View {
    let settings: TestSettingsProvider & KeySettingsProvider
    
    init(settings: TestSettingsProvider & KeySettingsProvider) {
        self.settings = settings
    }
    
    var body: some View {
        VStack {
            HeaderView()
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "house")
                        Text("Home")
                    }
                try! KeySettingsView(settingsProvider: settings)
                    .tabItem {
                        Image(systemName: "person.badge.key")
                        Text("Private Key")
                    }
                try! TestSettingsView(settingsProvider: settings)
                    .tabItem {
                        Image(systemName: "testtube.2")
                        Text("Test Protocol")
                    }
            }.padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(settings: PreviewSettingsProvider())
    }
}
