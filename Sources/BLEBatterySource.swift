import Foundation
import CoreBluetooth

/// Bluetooth Low Energy uređaji koji imaju standardni "Battery Service" (0x180F) —
/// npr. Logitech MX miševi/tastature i mnogi drugi BLE uređaji.
final class BLEBatterySource: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onChange: (() -> Void)?
    /// Javlja kad Bluetooth postane dostupan (npr. odmah posle davanja dozvole).
    var onPoweredOn: (() -> Void)?

    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var levels: [UUID: Int] = [:]
    private let batteryService = CBUUID(string: "180F")
    private let batteryLevel = CBUUID(string: "2A19")

    var devices: [BatteryDevice] {
        var result: [BatteryDevice] = []
        for (id, peripheral) in peripherals {
            guard let level = levels[id] else { continue }
            let name = peripheral.name ?? BatteryDevice.fallbackName
            result.append(BatteryDevice(
                name: name,
                address: nil,
                kind: DeviceKind.guess(name: name, hint: nil),
                level: level,
                left: nil,
                right: nil,
                caseLevel: nil,
                sources: ["BLE"]
            ))
        }
        return result
    }

    /// Korisnik je dao Bluetooth dozvolu. Dok nije, IOBluetooth pozivi blokiraju glavnu nit
    /// (čekaju odgovor na sistemski dijalog), pa se do tada ne smeju pozivati.
    var isAccessGranted: Bool { CBManager.authorization == .allowedAlways }

    /// Korisnik je odbio (ili sistem ograničio) Bluetooth dozvolu.
    var isAccessDenied: Bool {
        let auth = CBManager.authorization
        return auth == .denied || auth == .restricted
    }

    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
        }
    }

    func refresh() {
        guard let manager = central, manager.state == .poweredOn else { return }
        let connected = manager.retrieveConnectedPeripherals(withServices: [batteryService])
        let connectedIDs = Set(connected.map { $0.identifier })

        var changed = false
        for id in Array(peripherals.keys) where !connectedIDs.contains(id) {
            peripherals[id] = nil
            if levels.removeValue(forKey: id) != nil { changed = true }
        }

        for peripheral in connected {
            peripherals[peripheral.identifier] = peripheral
            peripheral.delegate = self
            if peripheral.state == .connected {
                readBattery(of: peripheral)
            } else {
                // Uređaj je povezan sa sistemom; ovim se i aplikacija "zakači" na tu vezu.
                manager.connect(peripheral, options: nil)
            }
        }
        if changed { onChange?() }
    }

    private func readBattery(of peripheral: CBPeripheral) {
        let service = peripheral.services?.first(where: { $0.uuid == batteryService })
        if let characteristic = service?.characteristics?.first(where: { $0.uuid == batteryLevel }) {
            peripheral.readValue(for: characteristic)
        } else {
            peripheral.discoverServices([batteryService])
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            refresh()
            onPoweredOn?()
        } else {
            if !peripherals.isEmpty {
                peripherals.removeAll()
                levels.removeAll()
            }
            // I promena dozvole (npr. odbijena) treba da osveži meni.
            onChange?()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices([batteryService])
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        peripherals[peripheral.identifier] = nil
        if levels.removeValue(forKey: peripheral.identifier) != nil { onChange?() }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == batteryService }) else { return }
        peripheral.discoverCharacteristics([batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristic = service.characteristics?.first(where: { $0.uuid == batteryLevel }) else { return }
        peripheral.readValue(for: characteristic)
        if characteristic.properties.contains(.notify) && !characteristic.isNotifying {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == batteryLevel,
              let byte = characteristic.value?.first else { return }
        let level = Int(byte)
        guard (0...100).contains(level) else { return }
        if levels[peripheral.identifier] != level {
            levels[peripheral.identifier] = level
            onChange?()
        }
    }
}
