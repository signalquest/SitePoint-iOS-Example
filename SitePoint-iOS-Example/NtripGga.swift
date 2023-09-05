import Foundation
import CoreLocation

/// Uses Apple Location Services to get NMEA GGA Sentences for seeding NTRIP services.
///
/// This class doesn't use any SignalQuest services; it is only included to make using this example, with NTRIP services that require location seeding, easier.
///
/// To use, instantiate this class and use its ``string`` property.
///
/// **Please note**: Results will only be available if location permissions are accepted and after the iPhone/iPad starts returning locations.
class GgaGenerator {
    var locationService: AppleLocation
    
    /// An NMEA GGA Sentence, using the phone's current location, to pass to NTRIP services.
    var string: String {
        get {
            var gga = ""
            // could also use a SitePoint location
            if let location = locationService.appleLocation {
                // Convert CLLocation to GGA message
                let timestampFormatter = DateFormatter()
                timestampFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone?
                timestampFormatter.dateFormat = "HHmmss"
                
                var nmea0183GPGGA: String
                let latitude = convertCLLocationDegreesToNmea(degrees: location.coordinate.latitude)
                let longitude = convertCLLocationDegreesToNmea(degrees: location.coordinate.longitude)
                
                nmea0183GPGGA = "GPGGA," + timestampFormatter.string(from: location.timestamp)
                nmea0183GPGGA += String(format: ",%07.2f,", arguments: [abs(latitude)])
                nmea0183GPGGA += latitude > 0.0 ? "N" : "S"
                nmea0183GPGGA += String(format: ",%08.2f,", arguments: [abs(longitude)])
                nmea0183GPGGA += longitude > 0.0 ? "E" : "W"
                nmea0183GPGGA += ",1,10,1,"
                nmea0183GPGGA += String(format: "%1.1f,M,%1.1f,M,5,", arguments: [location.altitude, location.altitude])
                nmea0183GPGGA += String(format: "*%02lX", arguments: [nmeaSentenceChecksum(sentence: nmea0183GPGGA)])
                nmea0183GPGGA = "$" + nmea0183GPGGA
                gga = nmea0183GPGGA
            }
            return gga
        }
    }
    
    init() {
        self.locationService = AppleLocation()
        locationService.requestAuthorization()
    }
    
    private func convertCLLocationDegreesToNmea(degrees: CLLocationDegrees) -> Double {
        let degreeSign = degrees < 0.0 ? -1.0 : 1.0;
        let degree = abs(degrees);
        let degreeDecimal = floor(degree);
        let degreeFraction = degree - degreeDecimal;
        let minutes = degreeFraction * 60.0;
        let nmea = degreeSign * ((degreeDecimal * 100)  + minutes);
        return nmea;
    }
    
    private func nmeaSentenceChecksum(sentence: String) -> CLong {
        var checksum: unichar = 0;
        var stringUInt16 = [UInt16]()
        stringUInt16 += sentence.utf16
        for char in stringUInt16 {
            checksum ^= char
        }
        checksum &= 0x0ff
        return CLong(checksum)
    }
}

class AppleLocation: NSObject {
    var appleLocation:CLLocation?
    
    // Could disable when not sending
    private let locationManager = CLLocationManager()
    var locationAuthorization: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        self.locationManager.delegate = self
    }

    // Over-simplified request; does not handle rejection (system dialog no longer available;
    //  could send user straight to the location settings in that case)
    public func requestAuthorization() {
        self.locationManager.requestWhenInUseAuthorization()
    }
}

extension AppleLocation: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.locationAuthorization = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            appleLocation = location
        }
    }
}
