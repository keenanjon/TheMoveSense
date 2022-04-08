

import SwiftUI

struct Sensors: View {
    var peripheral: Peripheral
    var body: some View {
        ZStack {
            Color.blue
            VStack {
                Text("\(peripheral.name)")
                    .foregroundColor(Color.white)
                Text("\(peripheral.serial)")
                    .foregroundColor(Color.white)
            }
        }
    }
}
