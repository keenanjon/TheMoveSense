
import Foundation
import Movesense
import Movesense.MDS
import SwiftUI

class MoveSenseController: ObservableObject {
    private let mds = MDSWrapper()
    @Published var connectedPeripherals = [Peripheral]()
    func connect(peripheral: Peripheral) {
        mds.connectPeripheral(with: peripheral.uuid)
        connectedPeripherals.append(peripheral)
        print("Connect peripheral \(peripheral.name)")
        print("Connected devices on Controller \(connectedPeripherals)")
    }
    
    func disconnect(peripheral: Peripheral) {
        mds.disconnectPeripheral(with: peripheral.uuid)
        connectedPeripherals.remove(at: getIndexOfElement(peripheral: peripheral))
        print("Disconnect peripheral \(peripheral.name)")
        print("Connected devices on Controller \(connectedPeripherals)")
    }
    
    func getIndexOfElement(peripheral: Peripheral) -> Int {
        for i in connectedPeripherals.indices {
            if (connectedPeripherals[i].uuid == peripheral.uuid) {
                return i
            }
        }
        return -1
    }
    
    func shutDown() {
        mds.deactivate()
    }
}
