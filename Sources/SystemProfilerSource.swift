import Foundation

/// `system_profiler SPBluetoothDataType -json` — AirPods (L/D/kutija), Beats i
/// slušalice/miševe drugih proizvođača za koje macOS zna nivo baterije.
/// Sporiji je (1–3 s), zato se poziva u pozadini.
enum SystemProfilerSource {
    private static let batteryKeys: [(key: String, slot: Slot)] = [
        ("device_batteryLevelMain", .main),
        ("device_batteryLevel", .main),
        ("device_batteryLevelCombined", .main),
        ("device_batteryLevelLeft", .left),
        ("device_batteryLevelRight", .right),
        ("device_batteryLevelCase", .caseBox),
        // stariji macOS je koristio snake_case
        ("device_battery_level_main", .main),
        ("device_battery_level_left", .left),
        ("device_battery_level_right", .right),
        ("device_battery_level_case", .caseBox),
    ]

    private enum Slot { case main, left, right, caseBox }

    static func read() -> [BatteryDevice] {
        guard let data = runProfiler(),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let controllers = root["SPBluetoothDataType"] as? [[String: Any]] else {
            return []
        }

        var devices: [BatteryDevice] = []
        for controller in controllers {
            guard let connected = controller["device_connected"] as? [[String: Any]] else { continue }
            for entry in connected {
                for (name, value) in entry {
                    guard let props = value as? [String: Any] else { continue }
                    devices.append(makeDevice(name: name, props: props))
                }
            }
        }
        return devices
    }

    private static func makeDevice(name: String, props: [String: Any]) -> BatteryDevice {
        var device = BatteryDevice(
            name: name,
            address: BatteryDevice.normalizeAddress(props["device_address"] as? String),
            kind: DeviceKind.guess(name: name, hint: props["device_minorType"] as? String),
            level: nil,
            left: nil,
            right: nil,
            caseLevel: nil,
            sources: ["system_profiler"]
        )
        for (key, slot) in batteryKeys {
            guard let value = percent(props[key]) else { continue }
            switch slot {
            case .main: if device.level == nil { device.level = value }
            case .left: device.left = value
            case .right: device.right = value
            case .caseBox: device.caseLevel = value
            }
        }
        return device
    }

    /// "80%" / "80 %" / 80 → 80
    private static func percent(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            let v = number.intValue
            return (0...100).contains(v) ? v : nil
        }
        guard let text = value as? String else { return nil }
        let digits = String(text.filter { $0.isNumber })
        guard let v = Int(digits), (0...100).contains(v) else { return nil }
        return v
    }

    private static func runProfiler() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
