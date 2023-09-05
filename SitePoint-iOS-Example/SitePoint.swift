import Foundation
import CoreBluetooth
import MapKit
import struct os.Logger
import SitePointSdk

/// Handles reading to and writing from a SitePoint.
///
/// Writes RTCM to the SitePoint in the ``NtripRtcmDelegate`` implementation.
///
/// Receives messages from the MessageHandler in MessageReceiverDelegate methods (using the SitePointSdk).
///
/// Hooks up and parses other messages in the CBPeripheralDelegate.
class SitePointPeripheral:NSObject, ObservableObject {
    
    static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: SitePointPeripheral.self)
        )
    
    /// Service UUID for SitePoints used in ``BluetoothManager``. Used when scanning for SitePoints,
    ///   discovering Services with ``peripheral(_:didDiscoverServices:)``, and for querying the SitePoint Bluetooth Service.
    public static let sitePointServiceUuid      = CBUUID.init(string: "00000100-34ed-12ef-63f4-317792041d17")
    /// Characteristic UUID for writing RTCM to SitePoints for aiding.
    public static let rtcmCharacteristicUuid   = CBUUID.init(string: "00000102-34ed-12ef-63f4-317792041d17")
    /// Characteristic UUID for sending and receiving other data from a SitePoint.
    public static let messageCharacteristicUuid    = CBUUID.init(string: "00000105-34ed-12ef-63f4-317792041d17")
    
    var peripheral: CBPeripheral?
    
    public var rtcmCharacteristic: CBCharacteristic?

    public var name: String?
    public var locations: CLLocation?

    private let messageHandler:MessageHandler
    @Published var status:Status = Status()
    @Published var location:Location = Location()
    
    override init() {
        messageHandler = MessageHandler()
        super.init()
        messageHandler.delegate = self
    }
    
    /// Called from ``BluetoothManager`` when a SitePoint connects.
    func didConnect(_ peripheral: CBPeripheral) {
        self.peripheral = peripheral
        name = peripheral.name
        peripheral.delegate = self
    }
    
    /// Called from ``BluetoothManager`` when a SitePoint disconnects.
    func didDisconnect() {
        peripheral = nil
        self.name = ""
    }
    
    private func displayError(_ error:String) {
        AppDelegate.displayError(SitePointPeripheral.logger, error)
    }
}

extension SitePointPeripheral: NtripRtcmDelegate {
    /// Write RTCM messages to the connected peripheral's ``rtcmCharacteristic`` here.
    func ntripDidUpdate(_ message: Data) {
        if let peripheral = self.peripheral {
            if let rtcmChar = rtcmCharacteristic {
                let chunks = [UInt8](message).chunked(into: peripheral.maximumWriteValueLength(for: CBCharacteristicWriteType.withoutResponse))
                for chunk in chunks {
                    SitePointPeripheral.logger.trace("ntripDidUpdate sending \(chunk.map { String(format: "%02hhX", $0) }.joined(separator: " "))")
                    SitePointPeripheral.logger.debug("ntripDidUpdate diary \(Date().timeIntervalSince1970) \(chunk.count)B \(chunk[0...min(6, chunk.count)].map { String(format: "%02hhX", $0) }.joined(separator: " "))")
                    peripheral.writeValue(Data(bytes: chunk, count: chunk.count), for: rtcmChar, type: .withoutResponse)
                }
            }
        }
    }
}

extension SitePointPeripheral: MessageReceiverDelegate {
    func receive(status:Status) {
        self.status = status
    }
    
    func receive(location:Location) {
        self.location = location
    }
}

extension SitePointPeripheral: CBPeripheralDelegate {
    /// Call ``peripheral(_:didDiscoverCharacteristicsFor:error:)`` here for the SitePoint service (with the ``sitePointServiceUuid``).
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            SitePointPeripheral.logger.info("Discovered services \(services)")
            for service in services {
                if service.uuid == SitePointPeripheral.sitePointServiceUuid {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if error != nil {
            displayError("didWriteValueFor failed: \(error!)")
        }
    }
    
    /// Hook up the SitePoint characteristics to use here.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                switch characteristic.uuid {
                    case SitePointPeripheral.rtcmCharacteristicUuid:
                        self.rtcmCharacteristic = characteristic
                    case SitePointPeripheral.messageCharacteristicUuid:
                        self.messageHandler.messageCharacteristic = characteristic
                        peripheral.setNotifyValue(true, for: characteristic)
                    default:
                        SitePointPeripheral.logger.debug("Unhandled characteristic \(characteristic.uuid)")
                }
            }
        }
    }
    
    /// Send data from the message characteristic for parsing (results received using the MessageReceiverDelegate).
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if SitePointPeripheral.messageCharacteristicUuid == characteristic.uuid {
            if let err = error {
                displayError("didUpdateValueFor, unhandled: \(err)")
            } else if let value = characteristic.value {
                do {
                    try messageHandler.parse(data: value)
                } catch SdkError.withFailureStatus(let failureCode, let detail) {
                    displayError("didUpdateValueFor failure, code \(failureCode): \(detail)")
                } catch SdkError.unexpected(let detail) {
                    displayError("didUpdateValueFor failure: \(detail)")
                } catch {
                    displayError("didUpdateValueFor \(error)")
                }
            } else {
                SitePointPeripheral.logger.warning("No data")
            }
        }
    }
}


