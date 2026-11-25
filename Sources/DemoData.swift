#if DEBUG
import Foundation

/// Samo za Debug build-ove: `-DemoDevices` prikazuje izmišljene uređaje (za App Store screenshotove),
/// `-OpenMenu` odmah otvara meni posle pokretanja.
enum DemoData {
    static var isEnabled: Bool { ProcessInfo.processInfo.arguments.contains("-DemoDevices") }
    static var exportsStatusItem: Bool { ProcessInfo.processInfo.arguments.contains("-ExportStatusItem") }
    static var opensMenu: Bool { ProcessInfo.processInfo.arguments.contains("-OpenMenu") }

    static let devices: [BatteryDevice] = BatteryDevice.merge([[
        BatteryDevice(name: "AirPods Pro", address: nil, kind: .airpodsPro, level: nil,
                      left: 82, right: 79, caseLevel: 64, sources: ["Demo"]),
        BatteryDevice(name: "Wireless Mouse", address: nil, kind: .mouse, level: 57,
                      left: nil, right: nil, caseLevel: nil, sources: ["Demo"]),
        BatteryDevice(name: "Magic Keyboard", address: nil, kind: .keyboard, level: 14,
                      left: nil, right: nil, caseLevel: nil, sources: ["Demo"]),
        BatteryDevice(name: "Magic Trackpad", address: nil, kind: .trackpad, level: 91,
                      left: nil, right: nil, caseLevel: nil, sources: ["Demo"]),
        BatteryDevice(name: "Game Controller", address: nil, kind: .gamepad, level: 68,
                      left: nil, right: nil, caseLevel: nil, sources: ["Demo"]),
    ]])
}
#endif
