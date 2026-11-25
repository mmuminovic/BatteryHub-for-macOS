import Foundation
import IOKit

/// Apple Magic Keyboard / Mouse / Trackpad (i drugi HID uređaji koji prijavljuju
/// "BatteryPercent") — čita se direktno iz IORegistry-ja, brzo i bez dozvola.
enum HIDBatterySource {
    private static let serviceClasses = [
        "AppleDeviceManagementHIDEventService", // Apple Silicon + noviji macOS
        "IOAppleBluetoothHIDDriver",            // stariji Intel Mac-ovi
        "AppleBluetoothHIDKeyboard",
        "BNBMouseDevice",
        "BNBTrackpadDevice",
    ]

    static func read() -> [BatteryDevice] {
        var found: [BatteryDevice] = []
        for className in serviceClasses {
            guard let matching = IOServiceMatching(className) else { continue }
            var iterator: io_iterator_t = 0
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { continue }

            var service = IOIteratorNext(iterator)
            while service != 0 {
                if let device = makeDevice(from: service),
                   !found.contains(where: { $0.matches(device) }) {
                    found.append(device)
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        return found
    }

    /// Vrsta uređaja po HID usage-u, za sve povezane HID uređaje (i one bez "BatteryPercent").
    /// Ključ je `BatteryDevice.normalize(ime)`. Pomaže kad ime ne otkriva vrstu,
    /// npr. Logitech "MX MCHNCL M" koji bateriju šalje samo preko BLE-a.
    static func kindHints() -> [String: DeviceKind] {
        guard let matching = IOServiceMatching("IOHIDDevice") else { return [:] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else { return [:] }
        defer { IOObjectRelease(iterator) }

        var hints: [String: DeviceKind] = [:]
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            guard let transport = stringProperty(service, "Transport"), transport.hasPrefix("Bluetooth"),
                  let name = stringProperty(service, "Product"),
                  intProperty(service, "PrimaryUsagePage") == 1, // Generic Desktop
                  let usage = intProperty(service, "PrimaryUsage") else { continue }
            let kind: DeviceKind
            switch usage {
            case 6, 7: kind = .keyboard
            case 2: kind = .mouse
            case 4, 5: kind = .gamepad
            default: continue
            }
            hints[BatteryDevice.normalize(name)] = kind
        }
        return hints
    }

    private static func makeDevice(from service: io_object_t) -> BatteryDevice? {
        guard let percent = intProperty(service, "BatteryPercent"), (0...100).contains(percent) else { return nil }
        let name = stringProperty(service, "Product") ?? BatteryDevice.fallbackName
        return BatteryDevice(
            name: name,
            address: BatteryDevice.normalizeAddress(stringProperty(service, "DeviceAddress")),
            kind: DeviceKind.guess(name: name, hint: nil),
            level: percent,
            left: nil,
            right: nil,
            caseLevel: nil,
            sources: ["IOKit"]
        )
    }

    private static func rawProperty(_ service: io_object_t, _ key: String) -> AnyObject? {
        guard let unmanaged = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return unmanaged.takeRetainedValue()
    }

    private static func intProperty(_ service: io_object_t, _ key: String) -> Int? {
        (rawProperty(service, key) as? NSNumber)?.intValue
    }

    private static func stringProperty(_ service: io_object_t, _ key: String) -> String? {
        rawProperty(service, key) as? String
    }
}
