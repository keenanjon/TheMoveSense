//
//  MoveSenseController2.swift
//  MoveSenseApp
//
//  Not created by Jon Menna on 11.4.2022.
/*
import Foundation
import Movesense
import Movesense.MDS
import SwiftUI
import CoreBluetooth



protocol MovesenseControllerDelegate: class {

    func deviceDiscovered(_ device: MovesenseDeviceConcrete)

    func deviceConnecting(_ serialNumber: MovesenseSerialNumber)
    func deviceConnected(_ deviceInfo: MovesenseDeviceInfo,
                         _ connection: MovesenseConnection)
    func deviceDisconnected(_ serialNumber: MovesenseSerialNumber)

    func onControllerError(_ error: Error)
}

class MovesenseController: NSObject {

    weak var delegate: MovesenseControllerDelegate?

    private let jsonDecoder: JSONDecoder = JSONDecoder()
    private let bleController: MovesenseBleController
    private let mdsWrapper: MDSWrapper
    private var mdsVersionNumber: String?

    private weak var movesenseModel: MovesenseModel?

    init(model: MovesenseModel,
         bleController: MovesenseBleController) {

        self.movesenseModel = model
        self.bleController = bleController

        // Initialize MDSWrapper with a separate CBCentralManager created in BleController to prevent MDS from doing
        // state restoration for it during initialization, which pretty much messes up the peripheral connection states
        // for good.
        self.mdsWrapper = MDSWrapper(Bundle.main, centralManager: bleController.mdsCentralManager, deviceUUIDs: nil)

        super.init()

        mdsWrapper.delegate = self
        bleController.delegate = self
        subscribeToDeviceConnections()
        getMDSVersion()
    }

    func mdsVersion() -> String? {
        return mdsVersionNumber
    }

    func shutdown() {
        mdsWrapper.deactivate()
    }

    /// Start looking for Movesense devices
    func startScan() {
        bleController.startScan()
    }

    /// Stop looking for Movesense devices
    func stopScan() {
        bleController.stopScan()
    }

    /// Establish a connection to the specific Movesense device
    func connectDevice(_ serial: MovesenseSerialNumber) {
        guard let device = movesenseModel?[serial] else {
            delegate?.onControllerError(MovesenseError.controllerError("No such device."))
            return
        }

        guard device.isConnected == false else {
            delegate?.onControllerError(MovesenseError.controllerError("Already connected."))
            return
        }

        delegate?.deviceConnecting(serial)

        mdsWrapper.connectPeripheral(with: device.uuid)
    }

    /// Disconnect specific Movesense device
    func disconnectDevice(_ serial: MovesenseSerialNumber) {
        guard let device = movesenseModel?[serial] else {
            delegate?.onControllerError(MovesenseError.controllerError("No such device."))
            return
        }

        delegate?.deviceDisconnected(device.serialNumber)

        mdsWrapper.disconnectPeripheral(with: device.uuid)
    }

    private func getMDSVersion() {
        mdsWrapper.doGet(MovesenseConstants.mdsVersion,
                         contract: [:],
                         completion: {[weak self] (event) in
            guard let this = self else {
                NSLog("MovesenseController integrity error.")
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

    private func subscribeToDeviceConnections() {
        mdsWrapper.doSubscribe(
            MovesenseConstants.mdsConnectedDevices,
            contract: [:],
            response: { (response) in
                guard response.statusCode == MovesenseResponseCode.ok.rawValue,
                      response.method == MDSResponseMethod.SUBSCRIBE else {
                    NSLog("MovesenseController invalid response to connection subscription.")
                    // TODO: Propagate error
                    return
                }
            },
            onEvent: { [weak self] (event) in
                guard let this = self,
                      let delegate = this.delegate else {
                    NSLog("MovesenseController integrity error.")
                    // TODO: Propagate error
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

                    this.mdsWrapper.disableAutoReconnectForDevice(withSerial: deviceInfo.serialNumber)
                    let connection = MovesenseConnection(mdsWrapper: this.mdsWrapper,
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
}

extension MovesenseController: MovesenseBleControllerDelegate {

    func deviceFound(uuid: UUID, localName: String, serialNumber: String, rssi: Int) {
        let device = MovesenseDeviceConcrete(uuid: uuid, localName: localName,
                                      serialNumber: serialNumber, rssi: rssi)
        delegate?.deviceDiscovered(device)
    }
}

extension MovesenseController: MDSConnectivityServiceDelegate {

    func didFailToConnectWithError(_ error: Error?) {
        // NOTE: The error is a null pointer and accessing it will cause a crash
        delegate?.onControllerError(MovesenseError.controllerError("Did fail to connect."))
    }
}




enum MovesenseConstants {

    static let mdsConnectedDevices = "MDS/ConnectedDevices"
    static let mdsVersion = "MDS/Whiteboard/MdsVersion"
}

struct MovesenseEventContainer<T: Decodable>: Decodable {

    let body: T
    let uri: String
    let method: String
}

struct MovesenseResponseContainer<T: Decodable>: Decodable {

    let content: T
}

struct MovesenseConnectionInfo: Codable {

    let connectionType: String
    let connectionUuid: UUID
}

struct MovesenseDeviceEventBody: Codable {

    let serialNumber: String
    let connectionInfo: MovesenseConnectionInfo?
    let deviceInfo: MovesenseDeviceInfo?
}

struct MovesenseDeviceEventStatus: Codable {

    let status: MovesenseResponseCode
}

struct MovesenseDeviceEvent: Codable {

    let eventUri: String
    let eventStatus: MovesenseDeviceEventStatus
    let eventMethod: MovesenseMethod
    let eventBody: MovesenseDeviceEventBody
}

enum MovesenseObserverEventModel: ObserverEvent {

    case deviceDiscovered(_ device: MovesenseDevice)
    case modelError(_ error: Error)
}

class MovesenseModel: Observable {

    typealias ArrayType = [MovesenseDeviceConcrete]

    internal var observations: [Observation] = [Observation]()
    private(set) var observationQueue: DispatchQueue = DispatchQueue.global()

    private var devices: [MovesenseDeviceConcrete] = [MovesenseDeviceConcrete]()

    subscript(serial: MovesenseSerialNumber) -> MovesenseDevice? {
        return self.first { $0.serialNumber == serial }
    }

    func resetDevices() {
        observationQueue.sync {
            devices.removeAll { $0.deviceState == .disconnected }
        }
    }
}

// Collection protocol for hiding the actual data storage
extension MovesenseModel: Collection {

    typealias Index = ArrayType.Index
    typealias Element = ArrayType.Element

    var startIndex: Index { return devices.startIndex }
    var endIndex: Index { return devices.endIndex }

    subscript(index: Index) -> Element {
        return devices[index]
    }

    func index(after i: Index) -> Index {
        return devices.index(after: i)
    }
}

extension MovesenseModel: MovesenseControllerDelegate {

    func deviceDiscovered(_ device: MovesenseDeviceConcrete) {
        guard (self.contains { $0.serialNumber == device.serialNumber }) == false else {
            return
        }

        observationQueue.sync {
            devices.append(device)
            notifyObservers(MovesenseObserverEventModel.deviceDiscovered(device))
        }
    }

    func deviceConnecting(_ serialNumber: MovesenseSerialNumber) {
        guard let device = (self.first { $0.serialNumber == serialNumber }) else {
            let error = MovesenseError.integrityError("No such device for connecting.")
            notifyObservers(MovesenseObserverEventModel.modelError(error))
            return
        }

        device.deviceConnecting()
    }

    func deviceConnected(_ deviceInfo: MovesenseDeviceInfo,
                         _ connection: MovesenseConnection) {
        guard let device = (self.first { $0.serialNumber == deviceInfo.serialNumber }) else {
            let error = MovesenseError.integrityError("No such connected device.")
            notifyObservers(MovesenseObserverEventModel.modelError(error))
            return
        }

        device.deviceConnected(deviceInfo, connection)
    }

    func deviceDisconnected(_ serialNumber: String) {
        guard let device = (self.first { $0.serialNumber == serialNumber }) else {
            let error = MovesenseError.integrityError("No such disconnected device.")
            notifyObservers(MovesenseObserverEventModel.modelError(error))
            return
        }

        device.deviceDisconnected()
    }

    func onControllerError(_ error: Error) {
        notifyObservers(MovesenseObserverEventModel.modelError(error))
    }
}




// Request events
public enum MovesenseEvent {

    case acc(MovesenseRequest, MovesenseAcc)
    case ecg(MovesenseRequest, MovesenseEcg)
    case gyroscope(MovesenseRequest, MovesenseGyro)
    case magn(MovesenseRequest, MovesenseMagn)
    case imu(MovesenseRequest, MovesenseIMU)
    case heartRate(MovesenseRequest, MovesenseHeartRate)
}

extension MovesenseEvent: CustomStringConvertible {

    public var description: String {
        switch self {
        case .acc(let request, let acc): return "request\n\(request)\nacc\n\(acc)"
        case .ecg(let request, let ecg): return "request\n\(request)\necg\n\(ecg)"
        case .gyroscope(let request, let gyro): return "request\n\(request)\ngyro\n\(gyro)"
        case .magn(let request, let magn): return "request\n\(request)\nmagn\n\(magn)"
        case .imu(let request, let imu): return "request\n\(request)\nimu\n\(imu)"
        case .heartRate(let request, let hr): return "request\n\(request)\n\(hr.average) \(hr.rrData)"
        }
    }
}

extension MovesenseEvent: Codable {

    private enum CodingKeys: String, CodingKey {
        case acc
        case ecg
        case gyroscope
        case magn
        case imu
        case heartRate
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .acc(_, let acc):
            try container.encode(acc, forKey: .acc)
        case .ecg(_, let ecg):
            try container.encode(ecg, forKey: .ecg)
        case .gyroscope(_, let gyro):
            try container.encode(gyro, forKey: .gyroscope)
        case .magn(_, let magn):
            try container.encode(magn, forKey: .magn)
        case .imu(_, let imu):
            try container.encode(imu, forKey: .imu)
        case .heartRate(_, let hr):
            try container.encode(hr, forKey: .heartRate)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let acc = try? container.decode(MovesenseAcc.self, forKey: .acc) {
            self = MovesenseEvent.acc(MovesenseRequest(resourceType: .acc,
                                                       method: .subscribe,
                                                       parameters: nil),
                                      acc)
            return
        }

        if let ecg = try? container.decode(MovesenseEcg.self, forKey: .ecg) {
            self = MovesenseEvent.ecg(MovesenseRequest(resourceType: .ecg,
                                                       method: .subscribe,
                                                       parameters: nil),
                                      ecg)
            return
        }

        if let gyro = try? container.decode(MovesenseGyro.self, forKey: .gyroscope) {
            self = MovesenseEvent.gyroscope(MovesenseRequest(resourceType: .gyro,
                                                             method: .subscribe,
                                                             parameters: nil),
                                            gyro)
            return
        }

        if let magn = try? container.decode(MovesenseMagn.self, forKey: .magn) {
            self = MovesenseEvent.magn(MovesenseRequest(resourceType: .magn,
                                                             method: .subscribe,
                                                             parameters: nil),
                                            magn)
            return
        }

        if let imu = try? container.decode(MovesenseIMU.self, forKey: .imu) {
            self = MovesenseEvent.imu(MovesenseRequest(resourceType: .imu,
                                                             method: .subscribe,
                                                             parameters: nil),
                                            imu)
            return
        }

        if let hr = try? container.decode(MovesenseHeartRate.self, forKey: .heartRate) {
            self = MovesenseEvent.heartRate(MovesenseRequest(resourceType: .heartRate,
                                                             method: .subscribe,
                                                             parameters: nil),
                                            hr)
            return
        }

        throw MovesenseError.decodingError("Decoding Error: \(container)")
    }
}




public struct MovesenseRequest {

    public let resourceType: MovesenseResourceType
    public let method: MovesenseMethod
    public let parameters: [MovesenseRequestParameter]?

    public init(resourceType: MovesenseResourceType, method: MovesenseMethod, parameters: [MovesenseRequestParameter]?) {
        self.resourceType = resourceType
        self.method = method
        self.parameters = parameters
    }
}

internal extension MovesenseRequest {

    var contract: [String: Any] {
        let contract = parameters?.reduce([String: Any]()) { (dict, parameter) -> [String: Any] in
            if let parameterTuple = parameter.asContract() {
                var dictCopy = dict
                dictCopy[parameterTuple.0] = parameterTuple.1
                return dictCopy
            }
            return dict
        } ?? [:]

        return contract
    }

    var path: String {
        let pathParameters: String = (parameters?.compactMap { $0.asPath() }.joined()) ?? ""
        return resourceType.resourcePath + pathParameters
    }
}

public enum MovesenseRequestParameter {

    case dpsRange(_ gRange: UInt16)
    case gRange(_ gRange: UInt8)
    case interval(_ interval: UInt8)
    case isOn(_ isOn: Bool)
    case sampleRate(_ rate: UInt)
    case systemMode(_ mode: UInt8)
}

extension MovesenseRequestParameter: CustomStringConvertible {

    public var description: String {
        return "\(name): \(value)"
    }

    public var name: String {
        switch self {
        case .dpsRange: return "DPS Range"
        case .gRange: return "G Range"
        case .interval: return "Interval"
        case .isOn: return "Is On"
        case .sampleRate: return "Sample Rate"
        case .systemMode: return "System Mode"
        }
    }

    public var value: String {
        switch self {
        case .dpsRange(let dpsRange): return "\(dpsRange) deg/s"
        case .gRange(let gRange): return "\(gRange) G"
        case .interval(let interval): return "\(interval)"
        case .isOn(let isOn): return "\(isOn)"
        case .sampleRate(let rate): return "\(rate) Hz"
        case .systemMode(let mode): return "\(mode)"
        }
    }

    func asPath() -> String? {
        switch self {
        case .sampleRate(let rate): return "/\(rate)"
        default: return nil
        }
    }

    func asContract() -> (String, Any)? {
        switch self {
        case .dpsRange(let dpsRange): return ("config", ["DPSRange": dpsRange])
        case .gRange(let gRange): return ("config", ["GRange": gRange])
        case .interval(let interval): return ("Interval", interval)
        case .isOn(let isOn): return ("isOn", isOn)
        case .systemMode(let mode): return ("NewState", mode)
        default: return nil
        }
    }
}



//
//  MovesenseTypes.swift
//  MovesenseApi
//
//  Copyright © 2019 Movesense. All rights reserved.
//

public typealias MovesenseSerialNumber = String

public enum MovesenseMethod: String, Codable {
    case get = "GET"
    case put = "PUT"
    case del = "DEL"
    case post = "POST"
    case subscribe
    case unsubscribe
}

public enum MovesenseError: Error {
    case integrityError(String)
    case controllerError(String)
    case decodingError(String)
    case requestError(String)
    case deviceError(String)
}

public enum MovesenseResponseCode: Int, Codable {
    case unknown = 0
    case ok = 200
    case created = 201
    case badRequest = 400
    case notFound = 404
    case conflict = 409
}

public struct MovesenseAddressInfo: Codable {

    public let address: String
    public let name: String
}

public struct MovesenseInfo: Codable {

    public let manufacturerName: String
    public let brandName: String?
    public let productName: String
    public let variantName: String
    public let design: String?
    public let hwCompatibilityId: String
    public let serialNumber: String
    public let pcbaSerial: String
    public let swVersion: String
    public let hwVersion: String
    public let additionalVersionInfo: String?
    public let addressInfo: [MovesenseAddressInfo]
    public let apiLevel: String
}

public struct MovesenseDeviceInfo: Codable {

    public let description: String
    public let mode: Int
    public let name: String
    public let serialNumber: String
    public let swVersion: String
    public let hwVersion: String
    public let hwCompatibilityId: String
    public let manufacturerName: String
    public let pcbaSerial: String
    public let productName: String
    public let variantName: String
    public let addressInfo: [MovesenseAddressInfo]
}

public struct MovesenseHeartRate: Codable {

    public let average: Float
    public let rrData: [Int]
}

public struct MovesenseAcc: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
}

public struct MovesenseAccConfig: Codable {

    public let gRange: UInt8
}

public struct MovesenseAccInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt8]
}

public struct MovesenseAppInfo: Codable {

    public let name: String
    public let version: String
    public let company: String
}

public struct MovesenseEcg: Codable {

    public let timestamp: UInt32
    public let samples: [Int32]
}

public struct MovesenseEcgInfo: Codable {

    public let currentSampleRate: UInt16
    public let availableSampleRates: [UInt16]
    public let arraySize: UInt16
}

public struct MovesenseGyro: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
}

public struct MovesenseGyroConfig: Codable {

    public let dpsRange: UInt16
}

public struct MovesenseGyroInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt16]
}

public struct MovesenseMagn: Codable {

    public let timestamp: UInt32
    public let vectors: [MovesenseVector3D]
}

public struct MovesenseMagnInfo: Codable {

    public let sampleRates: [UInt16]
    public let ranges: [UInt16]
}

public struct MovesenseIMU: Codable {

    public let timestamp: UInt32
    public let accVectors: [MovesenseVector3D]
    public let gyroVectors: [MovesenseVector3D]
}

public struct MovesenseSystemEnergy: Codable {

    public let percentage: UInt8
    public let milliVolts: UInt16?
    public let internalResistance: UInt8?
}

public struct MovesenseSystemMode: Codable {

    let currentMode: UInt8
    let nextMode: UInt8?
}

public struct MovesenseVector3D: Codable {

    public let x: Float
    public let y: Float
    public let z: Float
}




public protocol ObserverEvent {}

public protocol Observer: class {

    func handleEvent(_ event: ObserverEvent)
}

extension Observer {

    func handleEvent(_ event: ObserverEvent) {
        assertionFailure("Observer::handleEvent not implemented.")
    }
}

public struct Observation {

    weak var observer: Observer?
}

public protocol Observable: class {

    var observations: [Observation] { get set }
    var observationQueue: DispatchQueue { get }

    func addObserver(_ observer: Observer)
    func removeObserver(_ observer: Observer)
    func notifyObservers(_ event: ObserverEvent)
}

public extension Observable {

    func addObserver(_ observer: Observer) {
        guard (observations.contains { $0.observer === observer } == false) else {
            NSLog("Observable::addObserver: Observer added already.")
            return
        }

         DispatchQueue.global().sync {
            observations.append(Observation(observer: observer))
        }
    }

    func removeObserver(_ observer: Observer) {
        DispatchQueue.global().sync {
            observations = observations.filter {
                ($0.observer != nil) && ($0.observer !== observer)
            }
        }
    }

    func notifyObservers(_ event: ObserverEvent) {
        observationQueue.async { [observations] in
            observations.compactMap { $0.observer }.forEach { $0.handleEvent(event) }
        }
    }
}




class MovesenseDeviceConcrete: MovesenseDevice {

    private enum Constants {
        static let connectionTimeout: Double = 10.0
    }

    let uuid: UUID
    let localName: String
    let serialNumber: MovesenseSerialNumber
    let rssi: Int

    // TODO: Implement notifications here
    var deviceState: MovesenseDeviceState

    var isConnected: Bool {
        return movesenseConnection != nil
    }

    var deviceInfo: MovesenseDeviceInfo? {
        return movesenseDeviceInfo
    }

    lazy var resources: [MovesenseResource] = deviceResources()

    var observations: [Observation] = [Observation]()
    var observationQueue: DispatchQueue = DispatchQueue.global()

    private var movesenseDeviceInfo: MovesenseDeviceInfo?
    private var movesenseConnection: MovesenseConnection?

    private var connectionTimeout: Timer?

    init(uuid: UUID, localName: String, serialNumber: String, rssi: Int) {
        self.uuid = uuid
        self.localName = localName
        self.serialNumber = serialNumber
        self.rssi = rssi
        self.deviceState = .disconnected
    }

    func sendRequest(_ request: MovesenseRequest,
                            observer: Observer) -> MovesenseOperation? {
        guard let connection = movesenseConnection else {
            let error = MovesenseError.requestError("No connection to device.")
            notifyObservers(MovesenseObserverEventDevice.deviceError(self, error))
            return nil
        }

        let operation = connection.sendRequest(request, serial: self.serialNumber, observer: observer)

        DispatchQueue.global().async { [weak operation] in
            self.notifyObservers(MovesenseObserverEventDevice.deviceOperationInitiated(self, operation: operation))
        }

        return operation
    }

    func sendRequest(_ request: MovesenseRequest,
                            handler: @escaping (MovesenseObserverEventOperation) -> Void) {
        guard movesenseConnection != nil else {
            let error = MovesenseError.requestError("No connection to device.")
            handler(MovesenseObserverEventOperation.operationError(error))
            return
        }

        let responseObserver = MovesenseResponseObserver(handler)
        responseObserver.observedOperation = sendRequest(request, observer: responseObserver)
    }

    func deviceConnecting() {
        deviceState = .connecting
        notifyObservers(MovesenseObserverEventDevice.deviceConnecting(self))

        connectionTimeout = Timer.scheduledTimer(withTimeInterval: Constants.connectionTimeout, repeats: false) { [weak self] _ in
            guard let this = self else { return }

            Movesense.api.disconnectDevice(this)
            let event = MovesenseObserverEventDevice.deviceError(this, MovesenseError.deviceError("Connection timeout."))
            this.notifyObservers(event)
        }
    }

    func deviceConnected(_ deviceInfo: MovesenseDeviceInfo,
                                  _ connection: MovesenseConnection) {
        movesenseDeviceInfo = deviceInfo
        movesenseConnection = connection

        connectionTimeout?.invalidate()
        connectionTimeout = nil

        connection.delegate = self

        deviceState = .connected
        notifyObservers(MovesenseObserverEventDevice.deviceConnected(self))
    }

    func deviceDisconnected() {
        movesenseDeviceInfo = nil
        movesenseConnection = nil

        connectionTimeout?.invalidate()
        connectionTimeout = nil

        deviceState = .disconnected
        notifyObservers(MovesenseObserverEventDevice.deviceDisconnected(self))
    }

    // TODO: Fetch from the actual device
    func deviceResources() -> [MovesenseResource] {
        return [MovesenseResourceAcc([13, 26, 52, 104, 208, 416, 833, 1666]),
                MovesenseResourceAccConfig([2, 4, 8, 16]),
                MovesenseResourceAccInfo(),
                MovesenseResourceAppInfo(),
                MovesenseResourceEcg([128, 256, 512]),
                MovesenseResourceEcgInfo(),
                MovesenseResourceInfo(),
                MovesenseResourceHeartRate(),
                MovesenseResourceGyro([13, 26, 52, 104, 208, 416, 833, 1666]),
                MovesenseResourceGyroConfig([245, 500, 1000, 2000]),
                MovesenseResourceGyroInfo(),
                MovesenseResourceMagn([13, 26, 52, 104, 208, 416, 833, 1666]),
                MovesenseResourceMagnInfo(),
                MovesenseResourceIMU([13, 26, 52, 104, 208, 416, 833, 1666]),
                MovesenseResourceLed(),
                MovesenseResourceSystemEnergy(),
                MovesenseResourceSystemMode([1, 2, 3, 4, 5, 10, 11, 12])]
    }
}

extension MovesenseDeviceConcrete: MovesenseConnectionDelegate {

    func onConnectionError(_ error: Error) {
        notifyObservers(MovesenseObserverEventDevice.deviceError(self, error))
    }
}

private class MovesenseResponseObserver: Observer {

    private var workItem: DispatchWorkItem?
    private var observedOperationEvent: MovesenseObserverEventOperation?

    var observedOperation: MovesenseOperation?

    init(_ handler: @escaping (MovesenseObserverEventOperation) -> Void) {
        // Capture a strong reference to self to prevent deallocation before the operation has finished
        self.workItem = DispatchWorkItem(block: { [self, handler] in
            guard let response = self.observedOperationEvent else { return }

            handler(response)
        })

        self.workItem?.notify(queue: DispatchQueue.global()) { [weak self] in
            // Release workItem which results in deallocation of self
            self?.workItem = nil
        }
    }

    func handleEvent(_ event: ObserverEvent) {
        guard let workItem = workItem else { return }

        if let event = event as? MovesenseObserverEventOperation {
            observedOperationEvent = event
        } else {
            let error = MovesenseError.integrityError("Invalid event observed.")
            observedOperationEvent = MovesenseObserverEventOperation.operationError(error)
        }

        // Execute workItem in the global queue to prevent it from blocking operation event handling
        DispatchQueue.global().async(execute: workItem)
    }
}



protocol MovesenseConnectionDelegate: class {

    func onConnectionError(_ error: Error)
}

class MovesenseConnection {

    private let connectionQueue: DispatchQueue

    private weak var jsonDecoder: JSONDecoder?
    private weak var mdsWrapper: MDSWrapper?

    internal weak var delegate: MovesenseConnectionDelegate?

    init(mdsWrapper: MDSWrapper, jsonDecoder: JSONDecoder, connectionInfo: MovesenseConnectionInfo) {
        self.mdsWrapper = mdsWrapper
        self.jsonDecoder = jsonDecoder
        self.connectionQueue = DispatchQueue(label: "com.movesesense.\(connectionInfo.connectionUuid)", target: .global())
    }

    // TODO: Implement request timeout, although device disconnection handling should cover most of the cases
    // swiftlint:disable:next cyclomatic_complexity
    internal func sendRequest(_ request: MovesenseRequest, serial: String,
                              observer: Observer) -> MovesenseOperation? {
        guard let mds = self.mdsWrapper,
              let jsonDecoder = self.jsonDecoder else {
            let error = MovesenseError.integrityError("MovesenseConnection::sendRequest error.")
            delegate?.onConnectionError(error)
            return nil
        }

        let resourcePath = "\(serial)/\(request.path)"
        let onCancel = {
            switch request.method {
            case .subscribe: mds.doUnsubscribe(resourcePath)
            default: return
            }
        }

        let operation = MovesenseOperationFactory.create(request: request,
                                                         observer: observer,
                                                         jsonDecoder: jsonDecoder,
                                                         onCancel: onCancel)

        // Decode response with the MovesenseOperation instance
        let onCompletion = { [connectionQueue, weak operation] (_ response: MDSResponse) in
            guard let operation = operation else { return }
            connectionQueue.async {
                operation.handleResponse(status: response.statusCode, header: response.header,
                                         data: response.bodyData)
            }
        }

        switch request.method {
        case .get: mds.doGet(resourcePath, contract: request.contract, completion: onCompletion)
        case .put: mds.doPut(resourcePath, contract: request.contract, completion: onCompletion)
        case .post: mds.doPost(resourcePath, contract: request.contract, completion: onCompletion)
        case .del: mds.doDelete(resourcePath, contract: request.contract, completion: onCompletion)
        case .unsubscribe: mds.doUnsubscribe(resourcePath)
        case .subscribe:
            let onEvent = { [connectionQueue, weak operation] (_ event: MDSEvent) in
                guard let operation = operation else {
                    mds.doUnsubscribe(resourcePath)
                    return
                }

                connectionQueue.async {
                    operation.handleEvent(header: event.header,
                                          data: event.bodyData)
                }
            }

            mds.doSubscribe(resourcePath, contract: request.contract,
                            response: onCompletion, onEvent: onEvent)
        }

        return operation
    }
}



protocol MovesenseBleControllerDelegate: class {

    func deviceFound(uuid: UUID, localName: String,
                     serialNumber: String, rssi: Int)
}

protocol MovesenseBleController: class {

    var delegate: MovesenseBleControllerDelegate? { get set }

    var mdsCentralManager: CBCentralManager? { get }

    func startScan()
    func stopScan()
}

final class MovesenseBleControllerConcrete: NSObject, MovesenseBleController {

    weak var delegate: MovesenseBleControllerDelegate?

    // Keep this one here to use the same queue with our own central
    private(set) var mdsCentralManager: CBCentralManager?

    private let bleQueue: DispatchQueue

    private var centralManager: CBCentralManager?

    override init() {
        self.bleQueue = DispatchQueue(label: "com.movesense.ble")
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: bleQueue, options: nil)
        mdsCentralManager = CBCentralManager(delegate: self, queue: bleQueue, options: nil)
    }

    func startScan() {
        guard let centralManager = centralManager else {
            NSLog("MovesenseBleController::stopScan integrity error.")
            return
        }

        if centralManager.state != .poweredOn {
            NSLog("MovesenseBleController::startScan Bluetooth not on.")
            return
        }

        centralManager.scanForPeripherals(withServices: Movesense.MOVESENSE_SERVICES,
                                          options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func stopScan() {
        guard let centralManager = centralManager else {
            NSLog("MovesenseBleController::stopScan integrity error.")
            return
        }

        if centralManager.state != .poweredOn {
            NSLog("MovesenseBleController::stopScan Bluetooth not on.")
            return
        }

        if centralManager.isScanning == false {
            return
        }

        centralManager.stopScan()
    }

    private func isMovesense(_ localName: String) -> Bool {
        let index = localName.firstIndex(of: " ") ?? localName.endIndex
        return localName[localName.startIndex..<index] == "Movesense"
    }

    private func parseSerial(_ localName: String) -> String? {
        guard isMovesense(localName),
              let idx = localName.range(of: " ", options: .backwards)?.lowerBound else {
            return nil
        }

        return String(localName[localName.index(after: idx)...])
    }
}

extension MovesenseBleControllerConcrete: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case CBManagerState.poweredOff:
            NSLog("centralManagerDidUpdateState: poweredOff")
        case CBManagerState.poweredOn:
            NSLog("centralManagerDidUpdateState: poweredOn")
        default:
            NSLog("centralManagerDidUpdateState: \(central.state.rawValue)")
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        //print("fuckety fuck!")
        guard let localName = peripheral.name,
              let serialNumber = parseSerial(localName) else {
            return
        }

        delegate?.deviceFound(uuid: peripheral.identifier, localName: localName,
                              serialNumber: serialNumber, rssi: RSSI.intValue)
    }
}


// Main access point to the API
extension Movesense {

    public static var api: MovesenseApi {
        return MovesenseApiConcrete.sharedInstance
    }
}

public enum MovesenseObserverEventOperation: ObserverEvent {

    case operationResponse(_ response: MovesenseResponse)
    case operationEvent(_ event: MovesenseEvent)
    case operationFinished
    case operationError(_ error: MovesenseError)
}

public protocol MovesenseOperation: Observable {

    var operationRequest: MovesenseRequest { get }
}

public enum MovesenseDeviceState {

    case disconnected
    case connecting
    case connected
}

public enum MovesenseObserverEventDevice: ObserverEvent {

    case deviceConnecting(_ device: MovesenseDevice)
    case deviceConnected(_ device: MovesenseDevice)
    case deviceDisconnected(_ device: MovesenseDevice)
    case deviceOperationInitiated(_ device: MovesenseDevice, operation: MovesenseOperation?)
    case deviceError(_ device: MovesenseDevice, _ error: Error)
}

public protocol MovesenseDevice: Observable {

    var deviceState: MovesenseDeviceState { get }
    var uuid: UUID { get }
    var localName: String { get }
    var serialNumber: MovesenseSerialNumber { get }
    var rssi: Int { get }
    var isConnected: Bool { get }
    var deviceInfo: MovesenseDeviceInfo? { get }
    var resources: [MovesenseResource] { get }

    func sendRequest(_ request: MovesenseRequest,
                     observer: Observer) -> MovesenseOperation?

    func sendRequest(_ request: MovesenseRequest,
                     handler: @escaping (MovesenseObserverEventOperation) -> Void)
}

public enum MovesenseApiError: Error {

    case connectionError(String)
    case initializationError(String)
    case operationError(String)
}

public enum MovesenseObserverEventApi: ObserverEvent {

    case apiDeviceDiscovered(_ device: MovesenseDevice)
    case apiDeviceConnecting(_ device: MovesenseDevice)
    case apiDeviceConnected(_ device: MovesenseDevice)
    case apiDeviceDisconnected(_ device: MovesenseDevice)
    case apiDeviceOperationInitiated(_ device: MovesenseDevice, operation: MovesenseOperation?)
    case apiError(_ error: Error)
}

public protocol MovesenseApi: Observable {

    func mdsVersion() -> String?
    func startScan()
    func stopScan()
    func resetScan()

    func connectDevice(_ device: MovesenseDevice)
    func disconnectDevice(_ device: MovesenseDevice)

    func startObservingDevice(_ device: MovesenseDevice, observer: Observer)
    func stopObservingDevice(_ device: MovesenseDevice, observer: Observer)

    func getDevices() -> [MovesenseDevice]

    func getResourcesForDevice(_ device: MovesenseDevice) -> [MovesenseResource]?

    func sendRequestForDevice(_ device: MovesenseDevice, request: MovesenseRequest,
                              observer: Observer) -> MovesenseOperation?

    func sendRequestForDevice(_ device: MovesenseDevice, request: MovesenseRequest,
                              handler: @escaping (MovesenseObserverEventOperation) -> Void)
}



public enum MovesenseResourceType: String, Codable {

    case acc
    case accConfig
    case accInfo
    case appInfo
    case ecg
    case ecgInfo
    case heartRate
    case gyro
    case gyroConfig
    case gyroInfo
    case magn
    case magnInfo
    case imu
    case info
    case led
    case systemEnergy
    case systemMode
}

public extension MovesenseResourceType {

    var resourcePath: String {
        switch self {
        case .acc: return "Meas/Acc"
        case .accConfig: return "Meas/Acc/Config"
        case .accInfo: return "Meas/Acc/Info"
        case .appInfo: return "Info/App"
        case .ecg: return "Meas/ECG"
        case .ecgInfo: return "Meas/ECG/Info"
        case .heartRate: return "Meas/HR"
        case .gyro: return "Meas/Gyro"
        case .gyroConfig: return "Meas/Gyro/Config"
        case .gyroInfo: return "Meas/Gyro/Info"
        case .magn: return "Meas/Magn"
        case .magnInfo: return "Meas/Magn/Info"
        case .imu: return "Meas/IMU6"
        case .info: return "Info"
        case .led: return "Component/Led"
        case .systemEnergy: return "System/Energy"
        case .systemMode: return "System/Mode"
        }
    }

    var resourceName: String {
        switch self {
        case .acc: return "Linear Acceleration"
        case .accConfig: return "ACC Config"
        case .accInfo: return "ACC Info"
        case .appInfo: return "App Info"
        case .ecg: return "Electrocardiography"
        case .ecgInfo: return "ECG Info"
        case .heartRate: return "Heart Rate"
        case .gyro: return "Gyroscope"
        case .gyroConfig: return "Gyroscope Config"
        case .gyroInfo: return "Gyroscope Info"
        case .magn: return "Magnetometer"
        case .magnInfo: return "Magnetometer Info"
        case .imu: return "IMU"
        case .info: return "Info"
        case .led: return "LED"
        case .systemEnergy: return "System Energy"
        case .systemMode: return "System Mode"
        }
    }

    var resourceAbbreviation: String {
        switch self {
        case .acc: return "ACC"
        case .ecg: return "ECG"
        case .heartRate: return "HRA"
        case .gyro: return "GYR"
        case .magn: return "MAGN"
        case .imu: return "IMU"
        default: return self.resourceName.prefix(3).uppercased()
        }
    }
}

// swiftlint:disable large_tuple
public protocol MovesenseResource {

    var resourceType: MovesenseResourceType { get }
    var methods: [MovesenseMethod] { get }
    var methodParameters: [(MovesenseMethod, String, Any.Type, String)] { get }

    func requestParameter(_ index: Int) -> MovesenseRequestParameter?
}

// Default implementations
public extension MovesenseResource {

    var methodParameters: [(MovesenseMethod, String, Any.Type, String)] { return [] }

    func requestParameter(_ index: Int) -> MovesenseRequestParameter? { return nil }
}

// TODO: The resources could be initialized from the device metadata,
// TODO: for now just specify them here
public struct MovesenseResourceAcc: MovesenseResource {

    internal let sampleRate: MovesenseMethodParameterSampleRate

    public let resourceType: MovesenseResourceType = .acc
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return sampleRate.values.map { rate in
            return (.subscribe, sampleRate.name, sampleRate.valueType, rate.description)
        }
    }

    init(_ sampleRates: [UInt]) {
        self.sampleRate = MovesenseMethodParameterSampleRate(values: sampleRates)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else { return nil }

        switch parameter.2 {
        case is UInt.Type:
            guard let value = UInt(parameter.3) else { return nil }
            return sampleRate.setter(value)
        default: return nil
        }
    }
}

public struct MovesenseResourceAccConfig: MovesenseResource {

    internal let gRange: MovesenseMethodParameterGRange

    public let resourceType: MovesenseResourceType = .accConfig
    public let methods: [MovesenseMethod] = [.get, .put]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return gRange.values.map { range in
            return (.put, gRange.name, gRange.valueType, range.description)
        }
    }

    init(_ gRanges: [UInt8]) {
        self.gRange = MovesenseMethodParameterGRange(values: gRanges)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else {
            return nil
        }

        switch parameter.2 {
        case is UInt8.Type:
            guard let value = UInt8(parameter.3) else { return nil }
            return gRange.setter(value)
        default: return nil
        }
    }
}

public struct MovesenseResourceAccInfo: MovesenseResource {

    public let resourceType: MovesenseResourceType = .accInfo
    public let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceAppInfo: MovesenseResource {

    public let resourceType: MovesenseResourceType = .appInfo
    public let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceEcg: MovesenseResource {

    internal let sampleRate: MovesenseMethodParameterSampleRate

    public let resourceType: MovesenseResourceType = .ecg
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return sampleRate.values.map { rate in
            return (.subscribe, sampleRate.name, sampleRate.valueType, rate.description)
        }
    }

    init(_ sampleRates: [UInt]) {
        self.sampleRate = MovesenseMethodParameterSampleRate(values: sampleRates)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else { return nil }

        switch parameter.2 {
        case is UInt.Type:
            guard let value = UInt(parameter.3) else { return nil }
            return sampleRate.setter(value)
        default: return nil
        }
    }
}

struct MovesenseResourceEcgInfo: MovesenseResource {

    let resourceType: MovesenseResourceType = .ecgInfo
    let methods: [MovesenseMethod] = [.get]
}

struct MovesenseResourceInfo: MovesenseResource {

    let resourceType: MovesenseResourceType = .info
    let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceHeartRate: MovesenseResource {

    public let resourceType: MovesenseResourceType = .heartRate
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]
}

public struct MovesenseResourceGyro: MovesenseResource {

    internal let sampleRate: MovesenseMethodParameterSampleRate

    public let resourceType: MovesenseResourceType = .gyro
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return sampleRate.values.map { rate in
            return (.subscribe, sampleRate.name, sampleRate.valueType, rate.description)
        }
    }

    init(_ sampleRates: [UInt]) {
        self.sampleRate = MovesenseMethodParameterSampleRate(values: sampleRates)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else { return nil }

        switch parameter.2 {
        case is UInt.Type:
            guard let value = UInt(parameter.3) else { return nil }
            return sampleRate.setter(value)
        default: return nil
        }
    }
}


public struct MovesenseResourceGyroConfig: MovesenseResource {

    internal let dpsRange: MovesenseMethodParameterDpsRange

    public let resourceType: MovesenseResourceType = .gyroConfig
    public let methods: [MovesenseMethod] = [.get, .put]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return dpsRange.values.map { range in
            return (.put, dpsRange.name, dpsRange.valueType, range.description)
        }
    }

    init(_ dpsRanges: [UInt16]) {
        self.dpsRange = MovesenseMethodParameterDpsRange(values: dpsRanges)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else {
            return nil
        }

        switch parameter.2 {
        case is UInt16.Type:
            guard let value = UInt16(parameter.3) else { return nil }
            return dpsRange.setter(value)
        default: return nil
        }
    }
}

struct MovesenseResourceGyroInfo: MovesenseResource {

    let resourceType: MovesenseResourceType = .gyroInfo
    let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceMagn: MovesenseResource {

    internal let sampleRate: MovesenseMethodParameterSampleRate

    public let resourceType: MovesenseResourceType = .magn
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return sampleRate.values.map { rate in
            return (.subscribe, sampleRate.name, sampleRate.valueType, rate.description)
        }
    }

    init(_ sampleRates: [UInt]) {
        self.sampleRate = MovesenseMethodParameterSampleRate(values: sampleRates)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else { return nil }

        switch parameter.2 {
        case is UInt.Type:
            guard let value = UInt(parameter.3) else { return nil }
            return sampleRate.setter(value)
        default: return nil
        }
    }
}

struct MovesenseResourceMagnInfo: MovesenseResource {

    let resourceType: MovesenseResourceType = .magnInfo
    let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceIMU: MovesenseResource {

    internal let sampleRate: MovesenseMethodParameterSampleRate

    public let resourceType: MovesenseResourceType = .imu
    public let methods: [MovesenseMethod] = [.subscribe, .unsubscribe]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return sampleRate.values.map { rate in
            return (.subscribe, sampleRate.name, sampleRate.valueType, rate.description)
        }
    }

    init(_ sampleRates: [UInt]) {
        self.sampleRate = MovesenseMethodParameterSampleRate(values: sampleRates)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else { return nil }

        switch parameter.2 {
        case is UInt.Type:
            guard let value = UInt(parameter.3) else { return nil }
            return sampleRate.setter(value)
        default: return nil
        }
    }
}

struct MovesenseResourceLed: MovesenseResource {

    internal let isOn: MovesenseMethodParameterIsOn = MovesenseMethodParameterIsOn()

    let resourceType: MovesenseResourceType = .led
    let methods: [MovesenseMethod] = [.put]

    var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return isOn.values.map { ledOn in
            return (.put, isOn.name, isOn.valueType, ledOn.description)
        }
    }

    func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else {
            return nil
        }

        switch parameter.2 {
        case is Bool.Type:
            guard let value = Bool(parameter.3) else { return nil }
            return isOn.setter(value)
        default: return nil
        }
    }
}

public struct MovesenseResourceSystemEnergy: MovesenseResource {

    public let resourceType: MovesenseResourceType = .systemEnergy
    public let methods: [MovesenseMethod] = [.get]
}

public struct MovesenseResourceSystemMode: MovesenseResource {

    let systemMode: MovesenseMethodParameterSystemMode

    public let resourceType: MovesenseResourceType = .systemMode
    public let methods: [MovesenseMethod] = [.get, .put]

    public var methodParameters: [(MovesenseMethod, String, Any.Type, String)] {
        return systemMode.values.map { mode in
            return (.put, systemMode.name, systemMode.valueType, mode.description)
        }
    }

    init(_ modes: [UInt8]) {
        self.systemMode = MovesenseMethodParameterSystemMode(values: modes)
    }

    public func requestParameter(_ index: Int) -> MovesenseRequestParameter? {
        guard let parameter = methodParameters[safe: index] else {
            return nil
        }

        switch parameter.2 {
        case is UInt8.Type:
            guard let value = UInt8(parameter.3) else { return nil }
            return systemMode.setter(value)
        default: return nil
        }
    }
}


class MovesenseOperationFactory {

    class func create(request: MovesenseRequest,
                      observer: Observer,
                      jsonDecoder: JSONDecoder,
                      onCancel: @escaping () -> Void) -> MovesenseOperationInternal {

        switch request.resourceType {
        case .systemMode: return MovesenseOperationSystemMode(request: request, observer: observer,
                                                              jsonDecoder: jsonDecoder, onCancel: onCancel)

        case .accConfig: return MovesenseOperationAccConfig(request: request, observer: observer,
                                                            jsonDecoder: jsonDecoder, onCancel: onCancel)

        case .gyroConfig: return MovesenseOperationGyroConfig(request: request, observer: observer,
                                                              jsonDecoder: jsonDecoder, onCancel: onCancel)

        default: return MovesenseOperationBase(request: request, observer: observer,
                                               jsonDecoder: jsonDecoder, onCancel: onCancel)
        }
    }
}

protocol MovesenseOperationInternal: MovesenseOperation {

    func handleResponse(status: Int, header: [AnyHashable: Any], data: Data)
    func handleEvent(header: [AnyHashable: Any], data: Data)
}

class MovesenseOperationBase: MovesenseOperationInternal {

    internal var observations: [Observation] = [Observation]()
    private(set) var observationQueue: DispatchQueue

    private let request: MovesenseRequest
    private let onCancel: () -> Void

    private weak var jsonDecoder: JSONDecoder?

    var operationRequest: MovesenseRequest {
        return request
    }

    init(request: MovesenseRequest,
         observer: Observer,
         jsonDecoder: JSONDecoder,
         onCancel: @escaping () -> Void) {
        self.observationQueue = DispatchQueue(label: "com.movesesense.\(request.resourceType.rawValue)", target: .global())
        self.request = request
        self.jsonDecoder = jsonDecoder
        self.onCancel = onCancel
        self.addObserver(observer)
    }

    deinit {
        notifyObservers(MovesenseObserverEventOperation.operationFinished)
        onCancel()
    }

    internal func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        guard let jsonDecoder = self.jsonDecoder else {
            throw MovesenseApiError.operationError("No decoder.")
        }

        return try jsonDecoder.decode(type, from: data)
    }

    // TODO: Only decode responses with success status code
    // swiftlint:disable:next cyclomatic_complexity
    internal func handleResponse(status: Int, header: [AnyHashable: Any], data: Data) {
        //print("Completion status: \(status)\nHeader:\n\(header)\n\(String(data: data, encoding: String.Encoding.utf8))")

        let response: MovesenseResponse?
        switch self.request.resourceType {
        case .accInfo:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseAccInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.accInfo(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                 self.request, decodedResponse.content)
        case .appInfo:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseAppInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.appInfo(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                 self.request, decodedResponse.content)
        case .ecgInfo:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseEcgInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.ecgInfo(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                 self.request, decodedResponse.content)
        case .gyroInfo:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseGyroInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.gyroInfo(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                  self.request, decodedResponse.content)
        case .magnInfo:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseMagnInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.magnInfo(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                  self.request, decodedResponse.content)
        case .info:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseInfo>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.info(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                              self.request, decodedResponse.content)
        case .systemEnergy:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseSystemEnergy>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.systemEnergy(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                      self.request, decodedResponse.content)
        case .systemMode:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseSystemMode>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.systemMode(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                    self.request, decodedResponse.content)
        case .acc, .ecg, .heartRate, .gyro, .magn, .imu, .led:
            response = MovesenseResponse.response(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                  self.request)
        default: response = nil
        }

        if let response = response {
            notifyObservers(MovesenseObserverEventOperation.operationResponse(response))
        } else {
            let error = MovesenseError.decodingError("Unable to decode response.")
            notifyObservers(MovesenseObserverEventOperation.operationError(error))
        }
    }

    internal func handleEvent(header: [AnyHashable: Any], data: Data) {
        //print("Event header:\n\(header)\n\(String(data: data, encoding: String.Encoding.utf8))")

        let event: MovesenseEvent?
        switch self.request.resourceType {
        case .acc:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseAcc>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.acc(self.request, decodedEvent.body)
        case .ecg:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseEcg>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.ecg(self.request, decodedEvent.body)
        case .gyro:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseGyro>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.gyroscope(self.request, decodedEvent.body)
        case .magn:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseMagn>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.magn(self.request, decodedEvent.body)
        case .imu:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseIMU>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.imu(self.request, decodedEvent.body)
        case .heartRate:
            guard let decodedEvent = try? decode(MovesenseEventContainer<MovesenseHeartRate>.self,
                                                 from: data) else {
                event = nil
                break
            }
            event = MovesenseEvent.heartRate(self.request, decodedEvent.body)
        default: event = nil
        }

        if let event = event {
            notifyObservers(MovesenseObserverEventOperation.operationEvent(event))
        } else {
            let error = MovesenseError.decodingError("Unable to decode event.")
            notifyObservers(MovesenseObserverEventOperation.operationError(error))
        }
    }
}

class MovesenseOperationSystemMode: MovesenseOperationBase {

    override func handleResponse(status: Int, header: [AnyHashable: Any], data: Data) {
        //print("Completion status: \(status)\nHeader:\n\(header)\n\(String(data: data, encoding: String.Encoding.utf8))")
        let response: MovesenseResponse?
        switch operationRequest.method {
        case .get:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseSystemMode>.self,
                                                    from: data) else {
                response = nil
                break
            }
            response = MovesenseResponse.systemMode(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                    operationRequest, decodedResponse.content)

        case .put:
            guard let parameter = (operationRequest.parameters?.first),
                  case let MovesenseRequestParameter.systemMode(requestedMode) = parameter else { return }

            response = MovesenseResponse.systemMode(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                    operationRequest, MovesenseSystemMode(currentMode: requestedMode,
                                                                                          nextMode: nil))
        default: response = nil
        }

        if let response = response {
          
            notifyObservers(MovesenseObserverEventOperation.operationResponse(response))
        } else {
            let error = MovesenseError.decodingError("Unable to decode response.")
            notifyObservers(MovesenseObserverEventOperation.operationError(error))
        }
    }
}

class MovesenseOperationAccConfig: MovesenseOperationBase {

    override func handleResponse(status: Int, header: [AnyHashable: Any], data: Data) {
        //print("Completion status: \(status)\nHeader:\n\(header)\n\(String(data: data, encoding: String.Encoding.utf8))")

        let response: MovesenseResponse?
        switch operationRequest.method {
        case .get:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseAccConfig>.self,
                                                    from: data) else {
                response = nil
                break
            }

            response = MovesenseResponse.accConfig(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                   operationRequest, decodedResponse.content)
        case .put:
            response = MovesenseResponse.accConfig(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                   operationRequest, nil)
        default: response = nil
        }

        if let response = response {
            notifyObservers(MovesenseObserverEventOperation.operationResponse(response))
        } else {
           
            let error = MovesenseError.decodingError("Unable to decode response.")
            notifyObservers(MovesenseObserverEventOperation.operationError(error))
        }
    }
}

class MovesenseOperationGyroConfig: MovesenseOperationBase {

    override func handleResponse(status: Int, header: [AnyHashable: Any], data: Data) {
        //print("Completion status: \(status)\nHeader:\n\(header)\n\(String(data: data, encoding: String.Encoding.utf8))")

        let response: MovesenseResponse?
        switch operationRequest.method {
        case .get:
            guard let decodedResponse = try? decode(MovesenseResponseContainer<MovesenseGyroConfig>.self,
                                                    from: data) else {
                response = nil
                break
            }

            response = MovesenseResponse.gyroConfig(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                    operationRequest, decodedResponse.content)
        case .put:
            response = MovesenseResponse.gyroConfig(MovesenseResponseCode.init(rawValue: status) ?? .unknown,
                                                    operationRequest, nil)
        default: response = nil
        }

        if let response = response {
            notifyObservers(MovesenseObserverEventOperation.operationResponse(response))
        } else {
            let error = MovesenseError.decodingError("Unable to decode response.")
            notifyObservers(MovesenseObserverEventOperation.operationError(error))
        }
    }
}




*/
