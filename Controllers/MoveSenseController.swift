
import Foundation
import Movesense
import Movesense.MDS

class MoveSenseController {
    private let mds = MDSWrapper()
    
    func connect(peripheral: Peripheral) {
        mds.connectPeripheral(with: peripheral.uuid)
    }
    
    func disconnect(peripheral: Peripheral) {
        mds.disconnectPeripheral(with: peripheral.uuid)
    }
    
    func shutDown() {
        mds.deactivate()
    }
}
