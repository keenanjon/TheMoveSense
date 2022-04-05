

import SwiftUI

struct Sensors: View {
    var peripheral: Peripheral
    var body: some View {
        ZStack {
            Color.blue
            Text("\(peripheral.name)")
                .foregroundColor(Color.white)
        }
    }
}
