//
//  ContentView.swift
//  MoveSenseApp
//
//  Created by Jon Menna on 24.3.2022.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Home()
                .tabItem() {
                    Image(systemName: "house")
                    Text("Home")
                }
            Data()
                .tabItem() {
                    Image(systemName: "recordingtape")
                    Text("Data")
                }
            Database()
                .tabItem() {
                    Image(systemName: "icloud.and.arrow.down")
                    Text("Database")
                }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
