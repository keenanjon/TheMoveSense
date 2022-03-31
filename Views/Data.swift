

import SwiftUI

struct Data: View {
    var body: some View {
        ZStack {
            Color.green
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
                .foregroundColor(Color.white)
        }
    }
}

struct Data_Previews: PreviewProvider {
    static var previews: some View {
        Data()
    }
}
