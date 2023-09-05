import Foundation

extension Array {
    
    /// Chunks data; useful for writing directly to a SitePoint's characteristics.
    ///
    /// **Please note**: This is not needed for calling SitePoint SDK functions that write to the SitePoint.
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

/// Helper functions for debugging.
extension Data {
    init(reading input: InputStream) {
        self.init()
        input.open()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            if read == 0 {
                break
            }
            if read != -1 {
                self.append(buffer, count: read)
            }
        }
        buffer.deallocate()
    }

    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }
    
    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let hexDigits = Array((options.contains(.upperCase) ? "0123456789ABCDEF" : "0123456789abcdef").utf16)
        var chars: [unichar] = []
        chars.reserveCapacity(2 * count)
        for byte in self {
            chars.append(hexDigits[Int(byte / 16)])
            chars.append(hexDigits[Int(byte % 16)])
        }
        return String(utf16CodeUnits: chars, count: chars.count)
    }
}

// For using Strings in View alerts
extension String: Identifiable {
    public typealias ID = Int
    public var id: Int {
        return hash
    }
}

// For app name lookup
extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}
