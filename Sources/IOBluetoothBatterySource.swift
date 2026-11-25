import Foundation
import IOBluetooth

/// Svi trenutno povezani klasični Bluetooth uređaji (i oni bez podatka o bateriji,
/// da bi se videli u meniju). Nivo baterije se čita preko nedokumentovanih
/// `batteryPercent*` svojstava IOBluetoothDevice-a — uvek uz proveru da postoje,
/// pa aplikacija ne može da pukne ako ih Apple ukloni.
enum IOBluetoothBatterySource {
    static func read() -> [BatteryDevice] {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return [] }

        var devices: [BatteryDevice] = []
        for device in paired where device.isConnected() {
            let name: String = device.name ?? device.addressString ?? BatteryDevice.fallbackName
            let single = percent(device, "batteryPercentSingle")
            let combined = percent(device, "batteryPercentCombined")
            devices.append(BatteryDevice(
                name: name,
                address: BatteryDevice.normalizeAddress(device.addressString),
                kind: DeviceKind.guess(name: name, hint: hint(forClassOfDevice: UInt32(device.classOfDevice))),
                level: single ?? combined,
                left: percent(device, "batteryPercentLeft"),
                right: percent(device, "batteryPercentRight"),
                caseLevel: percent(device, "batteryPercentCase"),
                sources: ["IOBluetooth"]
            ))
        }
        return devices
    }

    private static func percent(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)),
              let number = device.value(forKey: key) as? NSNumber else { return nil }
        let value = number.intValue
        // 0 znači "nepoznato" kod ovih svojstava
        return (1...100).contains(value) ? value : nil
    }

    /// Bluetooth "Class of Device" → tekstualni nagoveštaj za DeviceKind.guess.
    private static func hint(forClassOfDevice cod: UInt32) -> String? {
        let major = (cod >> 8) & 0x1F
        let minor = (cod >> 2) & 0x3F
        switch major {
        case 0x04: // Audio/Video
            switch minor {
            case 0x01, 0x02, 0x06: return "headphones"
            case 0x05, 0x0A: return "speaker"
            default: return nil
            }
        case 0x05: // Peripheral
            let subtype = minor & 0x0F
            if subtype == 0x01 || subtype == 0x02 { return "gamepad" }
            switch (minor >> 4) & 0x03 {
            case 0x01, 0x03: return "keyboard"
            case 0x02: return "pointing"
            default: return nil
            }
        default:
            return nil
        }
    }
}
