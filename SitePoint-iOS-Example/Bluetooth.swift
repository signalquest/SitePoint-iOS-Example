import Foundation
import struct os.Logger
import CoreBluetooth
import SitePointSdk

/// CBCentralManagerDelegate that scans for SitePoints and handles connections.
///
/// Also manages a list of discoverable SitePoints and handles SitePoint connect/disconnect events.
///
/// Scanning starts when centralManager is available (in centralManagerDidUpdateState, below).
class BluetoothManager: NSObject {
    
    private var centralManager: CBCentralManager?
    private var devicesToWhenFound: [CBPeripheral:Date] = [:]
    var devicesToScanStatus: [CBPeripheral:ScanStatus] = [:]
    private var scanStaleSeconds:Double = 5
    
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: BluetoothManager.self)
        )

    func start() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
        setUpRemoveStaleDevicesTimer()
    }
    
    private func setUpRemoveStaleDevicesTimer() {
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            let stalenessDate = Date.now.addingTimeInterval(-self.scanStaleSeconds)
            // looping on local keys var so we can delete from dictionary
            let keys = Array(self.devicesToWhenFound.keys)
            for key in keys {
                if let foundDate = self.devicesToWhenFound[key], foundDate < stalenessDate {
                    self.devicesToWhenFound.removeValue(forKey: key)
                }
            }
        }
    }
    
    func getDevices() -> [CBPeripheral] {
        let devicesSnapshot = Array(devicesToWhenFound.keys).sorted(by: { $0.name ?? "" < $1.name ?? "" });
        return devicesSnapshot;
    }
    
    func connect(_ peripheral: CBPeripheral) {
        centralManager?.connect(peripheral, options: nil)
        // much of the ad data is also available in the Status messages
        devicesToScanStatus.removeValue(forKey: peripheral)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        centralManager?.cancelPeripheralConnection(peripheral)
    }
    
    /// Whether the peripheral is already connected to a device.
    func connected(_ peripheral: CBPeripheral) -> Bool {
        return devicesToScanStatus[peripheral]?.connected ?? false
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    private func getScanStatus(_ advertisementData: [String: Any]) -> ScanStatus? {
        if let adData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? NSData {
            return ScanStatus(adData)
        }
        return nil
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            displayError("CBCentralManager is not powered on")
        } else {
            centralManager?.scanForPeripherals(withServices: [SitePointPeripheral.sitePointServiceUuid], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
            BluetoothManager.logger.info("Started scanning")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        devicesToWhenFound[peripheral] = Date()
        devicesToScanStatus[peripheral] = getScanStatus(advertisementData)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        AppDelegate.instance.sitePoint.didConnect(peripheral)
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        AppDelegate.instance.sitePoint.didDisconnect()
    }
    
    private func displayError(_ error:String) {
        AppDelegate.displayError(BluetoothManager.logger, error)
    }
}
