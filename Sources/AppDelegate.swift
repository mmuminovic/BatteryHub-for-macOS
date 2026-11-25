import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: BatteryMonitor?
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let monitor = BatteryMonitor()
        self.monitor = monitor
        statusBar = StatusBarController(monitor: monitor)
        monitor.start()
    }
}
