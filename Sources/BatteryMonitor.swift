import AppKit
import IOBluetooth

/// Skuplja podatke iz svih izvora, spaja ih i javlja promene UI-ju.
/// Osvežava se na 60 s, posle buđenja Mac-a i kad se uređaj poveže/odveže.
final class BatteryMonitor: NSObject {
    static let refreshInterval: TimeInterval = 60

    /// Poziva se na main thread-u kad god se lista uređaja promeni.
    var onChange: (([BatteryDevice]) -> Void)?

    private(set) var devices: [BatteryDevice] = []
    private(set) var lastUpdate: Date?

    /// Bluetooth dozvola je odbijena — meni nudi prečicu do podešavanja privatnosti.
    var isBluetoothAccessDenied: Bool { ble.isAccessDenied }

    private let ble = BLEBatterySource()
    private var hidCache: [BatteryDevice] = []
    private var bluetoothCache: [BatteryDevice] = []
    private var profilerCache: [BatteryDevice] = []
    private var kindHints: [String: DeviceKind] = [:]
    private var profilerRunning = false
    private var profilerPending = false

    private var timer: Timer?
    private var pendingRefresh: DispatchWorkItem?
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [IOBluetoothUserNotification] = []

    func start() {
        #if DEBUG
        if DemoData.isEnabled {
            devices = DemoData.devices
            lastUpdate = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: Date())
            onChange?(devices)
            return
        }
        #endif
        ble.onChange = { [weak self] in
            self?.registerBluetoothNotificationsIfAllowed()
            self?.publish()
        }
        // Kad korisnik da Bluetooth dozvolu, odmah osveži sve izvore (ne čekaj 60 s).
        ble.onPoweredOn = { [weak self] in
            self?.registerBluetoothNotificationsIfAllowed()
            self?.scheduleRefresh(after: 1)
        }
        // CoreBluetooth asinhrono traži dozvolu (sistemski dijalog) — glavna nit ostaje slobodna.
        ble.start()

        refresh()

        let timer = Timer(timeInterval: BatteryMonitor.refreshInterval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = 10
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        registerBluetoothNotificationsIfAllowed()
    }

    /// IOBluetooth se dira tek kad postoji Bluetooth dozvola: pre toga njegovi pozivi blokiraju
    /// glavnu nit dok korisnik ne odgovori na dijalog (ikonica se ne bi ni pojavila u menu baru).
    private func registerBluetoothNotificationsIfAllowed() {
        guard connectNotification == nil, ble.isAccessGranted else { return }
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(bluetoothDeviceConnected(_:device:))
        )
    }

    /// Brzi izvori odmah, system_profiler u pozadini.
    func refresh() {
        #if DEBUG
        if DemoData.isEnabled { return }
        #endif
        hidCache = HIDBatterySource.read()
        kindHints = HIDBatterySource.kindHints()
        bluetoothCache = ble.isAccessGranted ? IOBluetoothBatterySource.read() : []
        ble.refresh()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DumpSources") {
            let line = "SOURCES hid=\(hidCache.map { "\($0.name):\($0.level ?? -1)" }) "
                + "iobt=\(bluetoothCache.map { "\($0.name):\($0.displayLevel ?? -1)" }) "
                + "ble=\(ble.devices.map { "\($0.name):\($0.level ?? -1)" }) profiler=\(profilerCache.map { "\($0.name):\($0.displayLevel ?? -1)" })\n"
            FileHandle.standardError.write(line.data(using: .utf8)!)
        }
        #endif
        publish()
        runProfiler()
    }

    private func runProfiler() {
        if profilerRunning {
            profilerPending = true
            return
        }
        profilerRunning = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = SystemProfilerSource.read()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.profilerCache = result
                self.profilerRunning = false
                self.publish()
                if self.profilerPending {
                    self.profilerPending = false
                    self.runProfiler()
                }
            }
        }
    }

    private func publish() {
        // Redosled = prioritet podataka kad se isti uređaj pojavi u više izvora.
        let merged = BatteryDevice.merge([hidCache, profilerCache, bluetoothCache, ble.devices],
                                         kindHints: kindHints)
        lastUpdate = Date()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-DumpSources") {
            let line = "MERGED hints=\(kindHints) profiler=\(profilerCache.map { "\($0.name):\($0.kind)" }) "
                + "devices=\(merged.map { "\($0.name):\($0.kind):\($0.displayLevel ?? -1)" })\n"
            FileHandle.standardError.write(line.data(using: .utf8)!)
        }
        #endif
        guard merged != devices else { return }
        devices = merged
        onChange?(merged)
    }

    private func scheduleRefresh(after delay: TimeInterval) {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    // MARK: - Sistemski događaji

    @objc private func systemDidWake(_ notification: Notification) {
        scheduleRefresh(after: 5)
    }

    @objc private func bluetoothDeviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        if let note = device.register(
            forDisconnectNotification: self,
            selector: #selector(bluetoothDeviceDisconnected(_:device:))
        ) {
            disconnectNotifications.append(note)
        }
        // Uređaju treba par sekundi posle povezivanja da prijavi bateriju.
        scheduleRefresh(after: 3)
    }

    @objc private func bluetoothDeviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        disconnectNotifications.removeAll { $0 === notification }
        scheduleRefresh(after: 1)
    }
}
