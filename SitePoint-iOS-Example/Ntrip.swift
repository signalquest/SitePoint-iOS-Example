import Foundation
import struct os.Logger
import SitePointSdk

protocol NtripRtcmDelegate {
    func ntripDidUpdate(_ message: Data)
}

/// State machine for connecting to an NTRIP service.
///
/// Used when passing RTCM messages to SitePoints for NTRIP aiding.
class Ntrip: NSObject, StreamDelegate {
    public enum State {
        case idle,            // No active connections
             connecting,      // Connecting and authorizing
             req_aiding,      // Initial request for RTCM via a mountpoint
             active           // Streaming data from a mountpoint
    }
    public private(set) var state: State = .idle
    
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier!,
        category: String(describing: Ntrip.self)
    )
    
    public var rtcmDelegate: NtripRtcmDelegate?
    
    private func handleRtcm(_ message: Data) {
        rtcmDelegate?.ntripDidUpdate(message)
    }
    
    private func handleAuthorized(_ result:Result<Void, AuthorizationFailure>) {
        switch result {
            case .success:
                Ntrip.logger.debug("NTRIP auth success, active")
                state = .active
                if ntripService?.sendPosition ?? false {
                    // Start a repeating timer to send the latest GGA string (if any known)
                    sendGgaString()
                    startGgaTimer()
                }
            case .failure(let details):
                displayError("NTRIP auth failure: (\(details.status)) \(details.reason): \(details.description)")
                disconnect()
        }
    }

    private var ntripService: NtripService?

    // unwrapped (!) to set after super.init() call
    private var parser:NtripParser!
    private let gga:GgaGenerator
    private var ggaTimer: Timer?
    
    // Streams for connection to remote NTRIP server
    private var readStream: Unmanaged<CFReadStream>?
    private var writeStream: Unmanaged<CFWriteStream>?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    
    public override init() {
        self.gga = GgaGenerator()
        super.init()
        self.parser = NtripParser(self.handleAuthorized, self.handleRtcm)
    }
    
    public func connect(service: NtripService) {
        if let oldService = ntripService {
            Ntrip.logger.info("Disconnecting from \(String(describing: oldService))")
            disconnect()
        }
        
        let host = CFHostCreateWithName(nil, service.server as CFString).takeRetainedValue()
        CFHostStartInfoResolution(host, .addresses, nil)
        var success: DarwinBoolean = false
        if let addresses = CFHostGetAddressing(host, &success)?.takeUnretainedValue() as NSArray?,
           let theAddress = addresses.firstObject as? NSData {
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(theAddress.bytes.assumingMemoryBound(to: sockaddr.self), socklen_t(theAddress.length),
                           &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                state = .connecting
                ntripService = service
                
                CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                                   service.server as CFString,
                                                   UInt32(service.port),
                                                   &readStream,
                                                   &writeStream)
                inputStream = readStream!.takeRetainedValue()
                outputStream = writeStream!.takeRetainedValue()
                inputStream?.delegate = self
                outputStream?.delegate = self
                inputStream?.schedule(in: .current, forMode: .common)
                outputStream?.schedule(in: .current, forMode: .common)
                inputStream?.open()
                outputStream?.open()
            } else {
                Ntrip.logger.warning("Unhandled: unable to resolve hostname")
                state = .idle
            }
        } else {
            Ntrip.logger.warning("Unhandled: invalid hostname")
            state = .idle
        }
        
    }
    
    public func disconnect() {
        stopGgaTimer()
        inputStream?.close()
        outputStream?.close()
        ntripService = nil
        state = .idle
    }
    
    private func sendGgaString() {
        if ntripService?.sendPosition ?? false && state == .active {
            let serverRequest = "\(gga.string)\r\n"
            Ntrip.logger.debug("Sending GGA \(serverRequest)")
            let data = serverRequest.data(using: .utf8)!
            data.withUnsafeBytes {
                guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    displayError("Error creating server request")
                    return
                }
                outputStream?.write(pointer, maxLength: data.count)
            }
        }
    }
    
    private func startGgaTimer() {
        guard ggaTimer == nil else { return }
        ggaTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            self.sendGgaString()
        }
    }
    
    private func stopGgaTimer() {
        ggaTimer?.invalidate()
        ggaTimer = nil
    }
    
    private func requestAiding() {
        if let service = ntripService {
            Ntrip.logger.info("requestAiding for \(service.description)")
            state = .req_aiding
            // Create a BASE64 encoded username:password sequence for authentication
            let username = service.username
            let password = service.password
            let authString = "\(username):\(password)"
            let basicAuth = Data(authString.utf8).base64EncodedString()
            let serverRequest = "GET \(service.mountpoint) HTTP/1.1\r\nHost: \(service.server)\r\nAccept: */*\r\nUser-Agent: SignalQuest NTRIP Client/1.0\r\nAuthorization: Basic \(basicAuth)\r\nConnection: close\r\n\r\n"
            let data = serverRequest.data(using: .utf8)!
            Ntrip.logger.trace("requestAiding data: \(String(decoding: data, as: UTF8.self))")
            data.withUnsafeBytes {
                guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    displayError("Error creating NTRIP aiding server request")
                    return
                }
                outputStream?.write(pointer, maxLength: data.count)
            }
        } else {
            displayError("requestAiding: missing ntripService")
        }
    }
    
    private func handleOtherResponse(stream: InputStream) {
        let data = Data(reading: stream)
        let str = String(decoding: data, as: UTF8.self)
        Ntrip.logger.info("NTRIP: handleOtherResponse(), data = \(String(decoding: data, as: UTF8.self))")
        displayError("Unexpected NTRIP response: \(str.count) bytes: (\(str))")
        displayError("Data: \(data.hexEncodedString())")
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        if aStream == outputStream {
            Ntrip.logger.debug("handling output stream with stream event \(String(describing:eventCode)) and state \(String(describing: self.state))")
            switch eventCode {
                case Stream.Event.openCompleted:
                    break
                case Stream.Event.errorOccurred:
                    if let anError = aStream.streamError {
                        displayError("NTRIP output stream error occurred: \(anError.localizedDescription)")
                    }
                case Stream.Event.hasSpaceAvailable:
                    if state == .connecting {
                        guard let _ = ntripService?.mountpoint else {
                            displayError("Mountpoint unexpectedly nil")
                            return
                        }
                        if ntripService?.mountpoint == "" {
                            Ntrip.logger.info("An empty mountpoint can be used for listing mountpoints")
                        } else {
                            requestAiding()
                        }
                    }
                default:
                    AppDelegate.displayError(Ntrip.logger, "NTRIP stream unexpected event: \(eventCode.rawValue)")
            }
        } else if aStream == inputStream {
            Ntrip.logger.debug("handling input stream with stream event \(String(describing:eventCode)) and state \(String(describing: self.state))")
            switch eventCode {
                case Stream.Event.openCompleted:
                    break
                case Stream.Event.hasBytesAvailable:
                    switch state {
                        case .req_aiding:
                            // results handled by handleAuthorized
                            Ntrip.logger.debug("Parsing authorized")
                            parser.parseAuthorized(aStream as! InputStream)
                        case .active:
                            // results handled by handleRtcm
                            Ntrip.logger.debug("Parsing incoming RTCM")
                            parser.parseRtcm(aStream as! InputStream)
                        default:
                            handleOtherResponse(stream: aStream as! InputStream)
                }
            case Stream.Event.errorOccurred:
                if let anError = aStream.streamError {
                    displayError("NTRIP input stream error occurred: \(anError.localizedDescription)")
                    // Try to reconnect if we were disconnected while active
                    if let disconnectedService = ntripService {
                        disconnect()
                        connect(service: disconnectedService)
                    }
                }
            default:
                break
            }
        }
    }
    
    private func displayError(_ error:String) {
        AppDelegate.displayError(Ntrip.logger, error)
    }
}

struct NtripService: Codable {
    var server:String
    var port:Int
    var mountpoint:String
    var sendPosition:Bool
    var username:String
    var password:String
    
    public var description: String { return "NtripService: \(server):\(port)\(mountpoint)" }
}
