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
