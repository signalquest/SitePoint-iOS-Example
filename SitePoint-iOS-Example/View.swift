import SwiftUI
import SitePointSdk

struct ContentView: View {
    @EnvironmentObject var appDelegate: AppDelegate
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    SitePointSection()
                    NtripConfigSection()
                    if appDelegate.sitePointConnected {
                        StatusSection()
                        LocationSection()
                    } else {
                        Text("Status and Location will be available with a connected SitePoint")
                    }
                }
            }
            .alert(item: $appDelegate.alert) { a in
                    Alert(
                        title: Text("Alert"),
                        message: Text(a),
                        dismissButton: .default(Text("OK")) {
                            appDelegate.alert = nil
                        })
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Bundle.main.displayName ?? "SitePoint Example")
        }.navigationViewStyle(StackNavigationViewStyle())
    }}

struct SitePointSection: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var expanded = true
    
    var body: some View {
        DisclosureGroup("SitePoints", isExpanded: $expanded) {
            ForEach(appDelegate.peripherals, id: \.self) { peripheral in
                HStack{
                    Text(peripheral.name ?? "[Unnamed]")
                    Spacer()
                    Button(appDelegate.connectedToCurrentDevice(peripheral) ? "Disconnect" : "Connect", action: {
                        appDelegate.toggleConnection(peripheral)
                    }).buttonStyle(.bordered).disabled(appDelegate.connectedToAnotherDevice(peripheral))
                }}}}}

struct NtripConfigSection: View {
    @EnvironmentObject var appDelegate: AppDelegate
    @AppStorage("ntripServer") private var server = ""
    @AppStorage("ntripPort") private var port = "2101"
    @AppStorage("ntripUsername") private var username = ""
    @AppStorage("ntripPassword") private var password = ""
    @AppStorage("ntripSendPosition") private var sendPosition = false
    @AppStorage("ntripMountpoint") private var mountpoint = ""
    
    var body: some View {
        DisclosureGroup("Ntrip") {
            VStack {
                TextField("Server", text: $server)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                TextField("Port", text: $port)
                    .keyboardType(.numberPad)
                    .onChange(of: port) { newValue in
                        let filtered = newValue.filter { "0123456789".contains($0) }
                        if filtered != newValue {
                            self.port = filtered
                        }
                    }
                TextField("Username", text: $username)
                SecureField("Password", text: $password)
                TextField("Mountpoint", text: $mountpoint)
                Toggle("Send position", isOn: $sendPosition)
                Button(appDelegate.ntripActive ? "Disconnect" : "Connect", action: {
                    var mp = mountpoint
                    if (!mp.starts(with: "/")) {
                        mp = "/\(mp)"
                    }
                    
                    appDelegate.toggleNtrip(server, port, username, password, sendPosition, mp)
                }).buttonStyle(.bordered)
            }}}}

struct StatusSection: View {
    @EnvironmentObject var app: AppDelegate
    @EnvironmentObject var sitePoint:SitePointPeripheral
    @Environment(\.defaultMinListRowHeight) var minRowHeight
    
    @ViewBuilder
    var body: some View {
        let status = sitePoint.status

        DisclosureGroup("Status") {
            List {
                Row("battery", String(format: "%d%%", status.battery))
                Row("iTow", String(format: "%d ms", status.iTow))
                Row("time", status.time)
                Row("time (formatted)", Date(timeIntervalSince1970: TimeInterval(status.time)).formatted(date: .numeric, time: .standard))
                Row("satellites", status.satellites)
                Row("mode", status.mode)
                Row("modeLabel", status.modeLabel)
                Row("aidingQuality", status.aidingQuality.map{ $0 ? 1 : 0 })
            }.frame(minHeight: minRowHeight * 8)
                .listStyle(.plain)
                .listRowInsets(EdgeInsets())
        }}}

struct LocationSection: View {
    @EnvironmentObject var app: AppDelegate
    @EnvironmentObject var sitePoint:SitePointPeripheral
    @Environment(\.defaultMinListRowHeight) var minRowHeight

    @ViewBuilder
    var body: some View {
        let location = sitePoint.location
        
        DisclosureGroup("Location") {
            List {
                Row("iTow", String(format: "%d ms", location.iTow))
                Row("latitude", String(format: "%.8f°", location.latitude))
                Row("longitude", String(format: "%.8f°", location.longitude))
                Row("height", String(format: "%.3f m", location.height))
                Row("horizontalAccuracy", String(format: "%.3f m", location.horizontalAccuracy))
                Row("verticalAccuracy", String(format: "%.3f m", location.verticalAccuracy))
            }.frame(minHeight: minRowHeight * 6)
                .listStyle(.plain)
                .listRowInsets(EdgeInsets())
        }}}

struct Row: View {
    let title: String
    let value: Any

    init(_ title: String, _ value: Any) {
        self.title = title
        self.value = value
    }
    
    var body: some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Text(String(describing: value))
        }}}
