//
//  Home.swift
//  MoveSenseApp
//
//  Created by iosdev on 31.3.2022.
//

import SwiftUI

struct Home: View {
    var body: some View {
        ZStack {
            Color.red
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                .foregroundColor(Color.white)
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}
