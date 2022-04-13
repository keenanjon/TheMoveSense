
import SwiftUI

struct Home: View {
    @ObservedObject var bleManager = BLEManager()
    @ObservedObject var moveSensecontroller = MoveSenseiController()
    @State private var isDisplayed = false
    @State private var isScanning = false
    @State private var toggles: [Bool] = [Bool]()
    
    init() {
        UITableView.appearance().backgroundColor = .clear // For tableView
        UITableViewCell.appearance().backgroundColor = .clear // For tableViewCell
    }
    
    var body: some View {
        let connectedDevices = moveSensecontroller.connectedPeripherals.map {$0.name}
        NavigationView {
            ZStack {
                Image("factory")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity)
                
                VStack {
                    VStack {
                        Text("Movesenses")
                            .padding()
                            .font(.largeTitle)
                            .foregroundColor(Color.white)
                            .frame(maxWidth: .infinity)
                            .background(
                                .gray
                                    .opacity(0.8)
                            )
                    } .cornerRadius(10)
                    Spacer()
                    
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
                    }
                    
                    Spacer()
                    
                    VStack {
                        if bleManager.isSwitchedOn {
                            HStack {
                                Text("Bluetooth:")
                                Text("ON")
                                    .foregroundColor(.green)
                            }
                        }
                        else {
                            HStack {
                                Text("Bluetooth:")
                                Text("OFF")
                                    .foregroundColor(.red)
                            }
                        }
                    }.font(.headline)
                    
                    //                    .padding()
                    //                    .frame(maxWidth: .infinity)
                    //                    .background(
                    //                        .gray
                    //                        .opacity(0.8)
                    //                    )
                    //                    .cornerRadius(10)
                    
                    ZStack {
                        VStack {
                            if !isScanning {
                                Button(action: {
                                    for peripheral in bleManager.peripherals where connectedDevices.contains(peripheral.name){
                                        moveSensecontroller.disconnect(peripheral: peripheral)
                                    }
                                    isScanning = true
                                    self.bleManager.startScanning()
                                }) {
                                    Text("Start Scanning")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            .gray
                                                .opacity(0.8)
                                        )
                                        .foregroundColor(Color.white)
                                        .cornerRadius(10)
                                    
                                }
                            }
                        } .padding(.bottom, 30)
                        
                        VStack {
                            if isScanning {
                                Button(action: {
                                    self.bleManager.stopScanning()
                                    isScanning = false
                                }) {
                                    Text("Stop Scanning")
                                        .padding()
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            .gray
                                                .opacity(0.8)
                                        )
                                        .foregroundColor(Color.white)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.bottom, 30)
                    }
                }
                .padding()
            } .navigationBarHidden(true)
        }
    }
}

