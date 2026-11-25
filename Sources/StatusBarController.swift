import AppKit
import ServiceManagement

/// Stack view koji ne "guta" klikove — svi klikovi idu na dugme status item-a.
final class PassthroughStackView: NSStackView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

enum Symbols {
    static func image(_ names: [String], pointSize: CGFloat = 13, weight: NSFont.Weight = .regular) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        for name in names {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                return image
            }
        }
        return nil
    }

    static func batteryNames(for level: Int) -> [String] {
        switch level {
        case ..<13: return ["battery.0percent", "battery.0"]
        case ..<38: return ["battery.25percent", "battery.25"]
        case ..<63: return ["battery.50percent", "battery.50", "battery.25"]
        case ..<88: return ["battery.75percent", "battery.75", "battery.100"]
        default: return ["battery.100percent", "battery.100"]
        }
    }
}

/// Menu bar prikaz: raširen = ikonica + % za svaki uređaj, skupljen = jedna ikonica.
/// Klik otvara meni sa detaljima, ⌥-klik odmah skuplja/širi.
final class StatusBarController: NSObject, NSMenuDelegate {
    private enum Layout {
        static let padding: CGFloat = 5
        static let deviceSpacing: CGFloat = 9
        static let iconTextSpacing: CGFloat = 3
        static let fontSize: CGFloat = 12
    }

    private let monitor: BatteryMonitor
    private let statusItem: NSStatusItem
    private let content = PassthroughStackView()
    private var devices: [BatteryDevice] = []

    /// Namerno se ne pamti između pokretanja — aplikacija se UVEK pokreće raširena.
    private var isExpanded = true

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init(monitor: BatteryMonitor) {
        self.monitor = monitor
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        statusItem.autosaveName = "BatteryHubStatusItem"
        configureButton()

        monitor.onChange = { [weak self] devices in
            self?.devices = devices
            self?.render()
        }
        render()

        #if DEBUG
        if DemoData.exportsStatusItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.exportStatusItemImages() }
        }
        if DemoData.opensMenu {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let button = self?.statusItem.button else { return }
                if let frame = button.window?.frame {
                    print("BatteryHub status item frame: \(NSStringFromRect(frame))")
                }
                button.performClick(nil)
            }
        }
        #endif
    }

    #if DEBUG
    /// `-ExportStatusItem`: crta sadržaj status item-a (isti SF Symbols, font, boje i razmaci kao
    /// u menu baru; raširen i skupljen, za tamnu i svetlu traku) u PNG na 4x — za oštre App Store
    /// screenshotove. Šalje se kroz stderr (base64) jer je kontejner zaštićen od drugih procesa.
    private func exportStatusItemImages() {
        let withBattery = devices.filter { $0.displayLevel != nil }
        let scale: CGFloat = 4
        let height: CGFloat = 24
        for expanded in [true, false] {
            for (name, labelColor) in [("dark", NSColor.white), ("light", NSColor.black)] {
                // (ikonica, tekst, boja) za svaki element
                var cells: [(NSImage?, String?, NSColor)] = []
                if expanded {
                    for device in withBattery {
                        let tint = device.isLow ? NSColor.systemRed : labelColor
                        cells.append((Symbols.image(device.kind.symbolNames), "\(device.displayLevel ?? 0)%", tint))
                    }
                } else if let weakest = withBattery.compactMap({ $0.displayLevel }).min() {
                    let tint = weakest <= BatteryDevice.lowThreshold ? NSColor.systemRed : labelColor
                    cells.append((Symbols.image(Symbols.batteryNames(for: weakest), pointSize: 14), nil, tint))
                }
                let font = NSFont.monospacedDigitSystemFont(ofSize: Layout.fontSize, weight: .medium)
                func tinted(_ image: NSImage?, _ color: NSColor) -> NSImage? {
                    image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
                }
                var width = Layout.padding * 2
                for (index, cell) in cells.enumerated() {
                    if index > 0 { width += Layout.deviceSpacing }
                    width += cell.0?.size.width ?? 0
                    if let text = cell.1 {
                        width += Layout.iconTextSpacing + (text as NSString).size(withAttributes: [.font: font]).width
                    }
                }
                width = ceil(width)
                guard let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
                rep.size = NSSize(width: width, height: height) // pre konteksta, da crtanje bude na 4x
                guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { continue }
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = ctx
                var x = Layout.padding
                for (index, cell) in cells.enumerated() {
                    if index > 0 { x += Layout.deviceSpacing }
                    if let image = tinted(cell.0, cell.2) {
                        let size = image.size
                        image.draw(in: NSRect(x: x, y: (height - size.height) / 2, width: size.width, height: size.height))
                        x += size.width
                    }
                    if let text = cell.1 {
                        x += Layout.iconTextSpacing
                        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: cell.2]
                        let size = (text as NSString).size(withAttributes: attributes)
                        (text as NSString).draw(at: NSPoint(x: x, y: (height - size.height) / 2), withAttributes: attributes)
                        x += size.width
                    }
                }
                NSGraphicsContext.restoreGraphicsState()
                guard let png = rep.representation(using: .png, properties: [:]) else { continue }
                let file = "statusitem-\(expanded ? "expanded" : "collapsed")-\(name)@4x.png"
                FileHandle.standardError.write("EXPORT \(file) \(png.base64EncodedString())\n".data(using: .utf8)!)
            }
        }
    }
    #endif

    // MARK: - Menu bar

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = nil
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = Layout.deviceSpacing
        content.translatesAutoresizingMaskIntoConstraints = false
        content.setHuggingPriority(.required, for: .horizontal)
        button.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Layout.padding),
            content.centerYAnchor.constraint(equalTo: button.centerYAnchor),
        ])
    }

    private func render() {
        let withBattery = devices.filter { $0.displayLevel != nil }

        let views: [NSView]
        if isExpanded && !withBattery.isEmpty {
            views = withBattery.map { makeDeviceCell($0) }
        } else {
            views = [makeCollapsedCell(withBattery)]
        }

        for old in content.arrangedSubviews {
            content.removeArrangedSubview(old)
            old.removeFromSuperview()
        }
        for view in views {
            content.addArrangedSubview(view)
        }

        content.layoutSubtreeIfNeeded()
        statusItem.length = ceil(content.fittingSize.width) + Layout.padding * 2

        let summary = tooltipText()
        statusItem.button?.toolTip = summary
        statusItem.button?.setAccessibilityLabel(summary)
    }

    private func makeDeviceCell(_ device: BatteryDevice) -> NSView {
        let level = device.displayLevel ?? 0
        let tint: NSColor = device.isLow ? .systemRed : .labelColor

        let icon = NSImageView()
        icon.image = Symbols.image(device.kind.symbolNames)
        icon.contentTintColor = tint
        icon.imageScaling = .scaleNone

        let label = NSTextField(labelWithString: "\(level)%")
        label.font = .monospacedDigitSystemFont(ofSize: Layout.fontSize, weight: .medium)
        label.textColor = tint

        let cell = NSStackView(views: [icon, label])
        cell.orientation = .horizontal
        cell.alignment = .centerY
        cell.spacing = Layout.iconTextSpacing
        return cell
    }

    private func makeCollapsedCell(_ withBattery: [BatteryDevice]) -> NSView {
        let icon = NSImageView()
        icon.imageScaling = .scaleNone
        if let weakest = withBattery.compactMap({ $0.displayLevel }).min() {
            icon.image = Symbols.image(Symbols.batteryNames(for: weakest), pointSize: 14)
            icon.contentTintColor = weakest <= BatteryDevice.lowThreshold ? .systemRed : .labelColor
        } else {
            icon.image = Symbols.image(["minus.plus.batteryblock", "battery.100"], pointSize: 14)
            icon.contentTintColor = .labelColor
        }
        return icon
    }

    private func tooltipText() -> String {
        if devices.isEmpty { return L("tooltip.empty") }
        return devices.map { "\($0.name): \($0.detailText)" }.joined(separator: "\n")
    }

    // MARK: - Klik

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            toggleExpanded()
            return
        }
        statusItem.menu = buildMenu()
        sender.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // Skidamo meni da bi sledeći klik ponovo prošao kroz statusItemClicked (⌥-klik).
        statusItem.menu = nil
    }

    // MARK: - Meni

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let header = NSMenuItem(title: L("menu.header"), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if monitor.isBluetoothAccessDenied {
            let denied = NSMenuItem(title: L("menu.bluetoothDenied"), action: #selector(openBluetoothPrivacySettings), keyEquivalent: "")
            denied.target = self
            denied.image = Symbols.image(["exclamationmark.triangle"])
            menu.addItem(denied)
        }

        if devices.isEmpty {
            let empty = NSMenuItem(title: L("menu.empty"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for device in devices {
                menu.addItem(makeDeviceMenuItem(device))
            }
        }

        menu.addItem(.separator())

        let toggle = NSMenuItem(
            title: isExpanded ? L("menu.collapse") : L("menu.expand"),
            action: #selector(toggleExpandedFromMenu),
            keyEquivalent: ""
        )
        toggle.target = self
        toggle.image = Symbols.image([isExpanded ? "arrow.down.right.and.arrow.up.left"
                                                 : "arrow.up.left.and.arrow.down.right"])
        toggle.toolTip = L("menu.toggleTip")
        menu.addItem(toggle)

        let refresh = NSMenuItem(title: L("menu.refresh"), action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        refresh.image = Symbols.image(["arrow.clockwise"])
        menu.addItem(refresh)

        let settings = NSMenuItem(title: L("menu.bluetoothSettings"), action: #selector(openBluetoothSettings), keyEquivalent: "")
        settings.target = self
        settings.image = Symbols.image(["gearshape"])
        menu.addItem(settings)

        let login = NSMenuItem(title: L("menu.launchAtLogin"), action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        if let updated = monitor.lastUpdate {
            let info = NSMenuItem(title: L("menu.updated", timeFormatter.string(from: updated)), action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }

        let about = NSMenuItem(title: L("menu.about"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        return menu
    }

    private func makeDeviceMenuItem(_ device: BatteryDevice) -> NSMenuItem {
        let item = NSMenuItem(title: device.name, action: #selector(openBluetoothSettings), keyEquivalent: "")
        item.target = self
        item.image = Symbols.image(device.kind.symbolNames, pointSize: 14)

        let paragraph = NSMutableParagraphStyle()
        paragraph.tabStops = [NSTextTab(textAlignment: .right, location: 300, options: [:])]

        let title = NSMutableAttributedString(
            string: device.name + "\t",
            attributes: [.font: NSFont.menuFont(ofSize: 0), .paragraphStyle: paragraph]
        )
        var detailAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium),
            .paragraphStyle: paragraph,
        ]
        if device.isLow {
            detailAttributes[.foregroundColor] = NSColor.systemRed
        } else if device.displayLevel == nil {
            detailAttributes[.foregroundColor] = NSColor.secondaryLabelColor
        }
        title.append(NSAttributedString(string: device.detailText, attributes: detailAttributes))
        item.attributedTitle = title
        item.toolTip = L("menu.deviceTip", device.kind.label, device.sources.joined(separator: ", "))
        return item
    }

    // MARK: - Akcije

    private func toggleExpanded() {
        isExpanded.toggle()
        render()
    }

    @objc private func toggleExpandedFromMenu() {
        toggleExpanded()
    }

    @objc private func refreshNow() {
        monitor.refresh()
    }

    @objc private func openBluetoothSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openBluetoothPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        activateApp()
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            showLoginItemError(error)
            return
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func showLoginItemError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L("loginError.title")
        alert.informativeText = error.localizedDescription + "\n\n" + L("loginError.hint")
        activateApp()
        alert.runModal()
    }
}
