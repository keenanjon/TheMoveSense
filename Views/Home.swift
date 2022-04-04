
import SwiftUI

struct Home: View {
    @ObservedObject var bleManager = BLEManager()
    @ObservedObject var moveSensecontroller = MoveSenseController()
    
    var body: some View {
        let connectedDevices = moveSensecontroller.connectedPeripherals.map {$0.name}
        
        VStack {
            
            Text("Movesenses")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, alignment: .center)
            List(bleManager.peripherals) { peripheral in
                HStack {
                    Text(peripheral.name)
                        .foregroundColor(connectedDevices.contains(peripheral.name) ? .green : .red)
                }
                .onTapGesture {
                    print("Clicked \(peripheral.name)")
                    
                    if (connectedDevices.contains(peripheral.name)) {
                        moveSensecontroller.disconnect(peripheral: peripheral)
                    } else {
                        moveSensecontroller.connect(peripheral: peripheral)
                    }
                }
            }.frame(height: 300)
            
            Spacer()
            
            Text("STATUS")
                .font(.headline)
            
            if bleManager.isSwitchedOn {
                Text("Bluetooth is switched on")
                    .foregroundColor(.green)
            }
            else {
                Text("Bluetooth is NOT switched on")
                    .foregroundColor(.red)
            }
            
            Spacer()
            
            HStack {
                VStack (spacing: 10) {
                    Button(action: {
                        self.bleManager.startScanning()
                    }) {
                        Text("Start Scanning")
                    }
                    
                }.padding()
                
                
                
                VStack (spacing: 10) {
                    Button(action: {
                        self.bleManager.stopScanning()
                    }) {
                        Text("Stop Scanning")
                    }
                }.padding()
            }
            Spacer()
            
        }
    }
}

struct Home_Previews: PreviewProvider {
    static var previews: some View {
        Home()
    }
}
