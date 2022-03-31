//
//  BLEManager.swift
//  MoveSenseApp
//
//  Created by Jon Menna on 31.3.2022.
//

import Foundation
import CoreBluetooth


struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    let uuid: UUID
}



class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate {
    
    var myCentral: CBCentralManager!
    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    
    override init() {
        super.init()
        
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
    }
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        }
        else {
            isSwitchedOn = false
        }
    }
    
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var peripheralName: String!
        
        if let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            print(name)
            peripheralName = name
            let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue, uuid: UUID(uuidString: peripheral.identifier.uuidString)!)
            print(newPeripheral)
            print(newPeripheral.name)
            if newPeripheral.name.contains("sense") {
                peripherals.append(newPeripheral)
            }
           
            
        }
        /*
         else {
         peripheralName = "Unknown"
         }
         */
        /*
         let newPeripheral = Peripheral(id: peripherals.count, name: peripheralName, rssi: RSSI.intValue)
         print(newPeripheral)
         peripherals.append(newPeripheral)
         */
    }
    
    func startScanning() {
        print("startScanning")
        myCentral.scanForPeripherals(withServices: nil, options: nil)
    }
    
    func stopScanning() {
        print("stopScanning")
        myCentral.stopScan()
    }
    
}
