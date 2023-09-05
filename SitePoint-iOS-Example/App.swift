import SwiftUI
import CoreBluetooth
import os
import CoreLocation

@main
/// App container.
struct SitePointDemoApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.sitePoint)
        }
    }
}

/// Initializes app and acts as a controller for the view.
class AppDelegate: NSObject, ObservableObject, UIApplicationDelegate {
    static private(set) var instance: AppDelegate! = nil
    private static let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier!,
            category: String(describing: AppDelegate.self)
        )
    
    @Published var peripherals:[CBPeripheral] = []
    @Published var alert:String?
    func addAlert(_ error:String) {
        if let a = alert {
            alert = "\(a)\n\(error)"
        } else {
            alert = error
        }
    }

    let btManager = BluetoothManager()
    var ntrip:Ntrip
    var sitePoint = SitePointPeripheral()
    
    var ntripActive: Bool {
        get {
            return ntrip.state != .idle
        }
    }

    var sitePointConnected: Bool {
        get {
            return sitePoint.peripheral != nil
        }
    }
    
    func connectedToCurrentDevice(_ peripheral:CBPeripheral) -> Bool {
        return peripheral == sitePoint.peripheral
    }
    
    func connectedToAnotherDevice(_ peripheral:CBPeripheral) -> Bool {
        return !connectedToCurrentDevice(peripheral) && btManager.connected(peripheral)
    }
    
    override init() {
        ntrip = Ntrip()
        ntrip.rtcmDelegate = sitePoint
        super.init()
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        AppDelegate.instance = self
        btManager.start()
        _ = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) {
            timer in self.peripherals = self.btManager.getDevices()
        }

        return true
    }
    
    func toggleConnection(_ peripheral: CBPeripheral) {
        if peripheral.name?.starts(with: "SQ-SPT-0020") ?? false {
            addAlert("The SQ-SPT-0020 SitePoint models are no longer supported. Please connect to a newer SitePoint to proceed.")
            return
        }
        
        let sitePointPeripheral = sitePoint.peripheral
        if let connected = sitePointPeripheral {
            btManager.disconnect(connected)
        }
        if peripheral != sitePointPeripheral {
            btManager.connect(peripheral)
        }
    }
    
    func toggleNtrip(_ server:String, _ port:String, _ username:String, _ password:String, _ sendPosition:Bool, _ mountpoint:String) {
        if ntripActive {
            ntrip.disconnect()
        } else {
            let service = NtripService(server: server, port: Int(port) ?? 2101, mountpoint: mountpoint, sendPosition: sendPosition, username: username, password: password)
            ntrip.connect(service: service)
        }
    }
    
    static func displayError(_ logger:Logger, _ error:String) {
        logger.error("\(error)")
        instance.addAlert(error)
    }
}
