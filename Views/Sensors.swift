

import SwiftUI

struct Sensors: View {
    
    let sensors = ["Accelerometer","Gyroscope","Magnetometer"]
    @State private var showGreeting = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header:
                            Text("Sensor 1")) {
                    ForEach(0 ..< sensors.count, id: \.self) {
                        Toggle(self.sensors[$0], isOn: $showGreeting)
                    }
                }
                Section(header:
                            Text("Sensor 2")) {
                    ForEach(0 ..< sensors.count, id: \.self) {
                        Toggle(self.sensors[$0], isOn: $showGreeting)
                    }
                }
                Section(header:
                            Text("Sensor 3")) {
                    ForEach(0 ..< sensors.count, id: \.self) {
                        Toggle(self.sensors[$0], isOn: $showGreeting)
                    }
                }
                
            } .navigationBarTitle("Sensors")
        }
    }
}




struct Sensors_Previews: PreviewProvider {
    static var previews: some View {
        Sensors()
    }
}
