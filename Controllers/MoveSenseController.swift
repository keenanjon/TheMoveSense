
import Foundation
import Movesense
import Movesense
import SwiftUI

protocol MoveSenseiControllerDelegate: class {

    func deviceDiscovered(_ device: MovesenseDeviceConcrete)

    func deviceConnecting(_ serialNumber: MovesenseSerialNumber)
    func deviceConnected(_ deviceInfo: MovesenseDeviceInfo,
                         _ connection: MovesenseConnection)
    func deviceDisconnected(_ serialNumber: MovesenseSerialNumber)

    func onControllerError(_ error: Error)
}


class MoveSenseiController: NSObject, ObservableObject{
    private let mds = MDSWrapper()
    
    weak var delegate: MoveSenseiControllerDelegate?
    private let jsonDecoder: JSONDecoder = JSONDecoder()
    @Published var connectedPeripherals = [Peripheral]()
    
    private var mdsVersionNumber: String?
    
    
    func getInfo(serial: String) {
        mds.doGet("suunto://174430000185/Info", contract: [:],
                  completion: {[weak self] (event) in
     guard let this = self else {
         NSLog("MovesenseController integrity error. GetInfo")
         // TODO: Propagate error
         return
     }

     // TODO: All decoding needs to be done asynchronously since it may take arbitrary time.
     // TODO: Do it here temporarily.
     guard let decodedEvent = try? this.jsonDecoder.decode(MovesenseResponseContainer<String>.self,
                                                           from: event.bodyData) else {
         let error = MovesenseError.decodingError("MovesenseController: unable to decode MDS version event.")
         NSLog(error.localizedDescription)
         this.delegate?.onControllerError(error)
         return
     }

     this.mdsVersionNumber = decodedEvent.content
 })
    }

 
    
    func connect(peripheral: Peripheral) {
        delegate?.deviceConnecting(peripheral.name.components(separatedBy: " ")[1])
        mds.connectPeripheral(with: peripheral.uuid)
        connectedPeripherals.append(peripheral)
        print("Connect peripheral \(peripheral.name)")
        print("Connected devices on Controller \(connectedPeripherals)")
        // "\(peripheral.name.components(separatedBy: " ")[1])MDS/ConnectedDevices"
        //getInfo(serial: peripheral.name.components(separatedBy: " ")[1])
        
        
        mds.doSubscribe("MDS/ConnectedDevices", contract:  [:], response: { (response) in
            guard response.statusCode == MovesenseResponseCode.ok.rawValue,
                  response.method == MDSResponseMethod.SUBSCRIBE else {
                NSLog("MovesenseController invalid response to connection subscription.")
                // TODO: Propagate error
                return
            }
            //print("RESPONSE: \(response.statusCode)")
            //print(self.delegate)
        }, onEvent: { [weak self] (event) in
            guard let this = self,
                  let delegate = this.delegate else {
                NSLog("MovesenseController integrity error")
                // TODO: Propagate error
                //print(event)
                return
            }

            // TODO: All decoding needs to be done asynchronously since it may take arbitrary time.
            // TODO: Do it here temporarily.
            guard let decodedEvent = try? this.jsonDecoder.decode(MovesenseDeviceEvent.self,
                                                                  from: event.bodyData) else {
                let error = MovesenseError.decodingError("MovesenseController: unable to decode device connection response.")
                NSLog(error.localizedDescription)
                this.delegate?.onControllerError(error)
                return
            }

            switch decodedEvent.eventMethod {
            case .post:
                guard let deviceInfo = decodedEvent.eventBody.deviceInfo,
                      let connectionInfo = decodedEvent.eventBody.connectionInfo else {
                    // TODO: What happens if throw is done here?
                    return
                }

                this.mds.disableAutoReconnectForDevice(withSerial: deviceInfo.serialNumber)
                let connection = MovesenseConnection(mdsWrapper: this.mds,
                                                     jsonDecoder: this.jsonDecoder,
                                                     connectionInfo: connectionInfo)
                delegate.deviceConnected(deviceInfo, connection)
            case .del:
                delegate.deviceDisconnected(decodedEvent.eventBody.serialNumber)
            default:
                NSLog("MovesenseController::subscribeToDeviceConnections unknown event method.")
                this.delegate?.onControllerError(MovesenseError.controllerError("Unknown event method"))
            }
        })
        
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
