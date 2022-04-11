
import SwiftUI

struct Home: View {
    @ObservedObject var bleManager = BLEManager()
    @ObservedObject var moveSensecontroller = MoveSenseController()
    @State private var isDisplayed = false
    @State private var isScanning = false
    @State  private var toggles: [Bool] = [Bool]()
    
    var body: some View {
        let connectedDevices = moveSensecontroller.connectedPeripherals.map {$0.name}
        NavigationView {
            VStack {
                Text("Movesenses")
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                List(bleManager.peripherals) { peripheral in
                    HStack {
                        Text(peripheral.name)
                            .foregroundColor(connectedDevices.contains(peripheral.name) ? .green : .red)
                            .onTapGesture {
                                print("Clicked \(peripheral.name)")
                                
                                if (connectedDevices.contains(peripheral.name)) {
                                    moveSensecontroller.disconnect(peripheral: peripheral)
                                    isDisplayed = false
                                } else {
                                    moveSensecontroller.connect(peripheral: peripheral)
                                    print(moveSensecontroller.objectWillChange)
                                    isDisplayed = true
                                    
                                }
                            }
                        
                        if (connectedDevices.contains(peripheral.name)) {
                            NavigationLink(destination: Sensors(peripheral: peripheral)) {
                                Button(action: {
                                    
                                }, label: {
                                    Text("Fetch data")
                                })
                            }
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
                
                ZStack {
                    VStack (spacing: 10) {
                        if !isScanning {
                            Button(action: {
                                for peripheral in bleManager.peripherals where connectedDevices.contains(peripheral.name){
                                    moveSensecontroller.disconnect(peripheral: peripheral)
                                }
                                isScanning = true
                                self.bleManager.startScanning()
                            }) {
                                Text("Start Scanning")
                            }
                        }
                    }.padding()
                    
                    VStack (spacing: 10) {
                        if isScanning {
                            Button(action: {
                                self.bleManager.stopScanning()
                                isScanning = false
                            }) {
                                Text("Stop Scanning")
                            }
                        }
                    }.padding()
                }
                Spacer()
            }
        }
    }
}



