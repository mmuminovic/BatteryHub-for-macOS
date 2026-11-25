import Foundation

/// Vrsta uređaja — određuje ikonicu u menu baru i redosled prikaza.
enum DeviceKind: Int {
    case airpods, airpodsPro, airpodsMax, headphones
    case mouse, trackpad, keyboard
    case gamepad, speaker, pencil, other

    /// Redosled u menu baru: slušalice, miš, trackpad, tastatura, ostalo.
    var sortOrder: Int {
        switch self {
        case .airpods, .airpodsPro, .airpodsMax, .headphones: return 0
        case .mouse: return 1
        case .trackpad: return 2
        case .keyboard: return 3
        case .gamepad: return 4
        case .speaker: return 5
        case .pencil: return 6
        case .other: return 7
        }
    }

    var label: String {
        switch self {
        case .airpods, .airpodsPro, .airpodsMax, .headphones: return L("kind.headphones")
        case .mouse: return L("kind.mouse")
        case .trackpad: return L("kind.trackpad")
        case .keyboard: return L("kind.keyboard")
        case .gamepad: return L("kind.gamepad")
        case .speaker: return L("kind.speaker")
        case .pencil: return L("kind.pencil")
        case .other: return L("kind.other")
        }
    }

    /// SF Symbols imena, po prioritetu (prvo koje postoji na sistemu se koristi).
    var symbolNames: [String] {
        switch self {
        case .airpods: return ["airpods", "headphones"]
        case .airpodsPro: return ["airpodspro", "airpods.pro", "airpods", "headphones"]
        case .airpodsMax: return ["airpodsmax", "airpods.max", "headphones"]
        case .headphones: return ["headphones"]
        case .mouse: return ["computermouse", "magicmouse", "cursorarrow"]
        case .trackpad: return ["rectangle.and.hand.point.up.left", "hand.point.up.left", "rectangle"]
        case .keyboard: return ["keyboard"]
        case .gamepad: return ["gamecontroller"]
        case .speaker: return ["hifispeaker", "speaker.wave.2"]
        case .pencil: return ["applepencil", "pencil"]
        case .other: return ["dot.radiowaves.left.and.right", "battery.100"]
        }
    }

    /// Pogađa vrstu uređaja iz imena i (opciono) sistemskog tipa ("Headphones", "Mouse"...).
    static func guess(name: String, hint: String?) -> DeviceKind {
        let n = name.lowercased()
        if n.contains("airpods max") { return .airpodsMax }
        if n.contains("airpods pro") { return .airpodsPro }
        if n.contains("airpods") { return .airpods }
        if n.contains("trackpad") { return .trackpad }
        if n.contains("controller") || n.contains("gamepad") || n.contains("dualsense")
            || n.contains("dualshock") || n.contains("xbox") || n.contains("joy-con") { return .gamepad }
        if n.contains("mouse") || n.contains("mx master") || n.contains("mx anywhere")
            || n.contains("miš") { return .mouse }
        if n.contains("keyboard") || n.contains("keys") || n.contains("mchncl") || n.contains("mechanical")
            || n.contains("tastatura") { return .keyboard }
        if n.contains("pencil") { return .pencil }

        if let h = hint?.lowercased() {
            if h.contains("headphone") || h.contains("headset") || h.contains("hands-free")
                || h.contains("handsfree") { return .headphones }
            if h.contains("mouse") || h.contains("pointing") { return .mouse }
            if h.contains("trackpad") { return .trackpad }
            if h.contains("keyboard") { return .keyboard }
            if h.contains("gamepad") || h.contains("joystick") { return .gamepad }
            if h.contains("speaker") { return .speaker }
        }

        let headphoneWords = ["beats", "buds", "headphone", "headset", "earbuds", "wh-", "wf-",
                              "bose", "jabra", "sennheiser", "momentum", "freebuds", "airdots", "slušalice"]
        if headphoneWords.contains(where: { n.contains($0) }) { return .headphones }
        if n.contains("speaker") || n.contains("jbl") || n.contains("boom") || n.contains("zvučnik") { return .speaker }
        return .other
    }
}

/// Jedan Bluetooth uređaj sa (opcionim) nivoima baterije.
struct BatteryDevice: Equatable {
    static let lowThreshold = 20

    var name: String
    var address: String?
    var kind: DeviceKind
    var level: Int?
    var left: Int?
    var right: Int?
    var caseLevel: Int?
    var sources: [String]

    /// Broj koji se prikazuje u menu baru: za AirPods slabija slušalica, inače glavna baterija.
    var displayLevel: Int? {
        let buds = [left, right].compactMap { $0 }
        if let weakest = buds.min() { return weakest }
        return level
    }

    var isLow: Bool {
        guard let value = displayLevel else { return false }
        return value <= BatteryDevice.lowThreshold
    }

    /// Fallback ime kad sistem ne prijavi ime uređaja.
    static var fallbackName: String { L("device.fallbackName") }

    /// Detaljan tekst za meni, npr. "L 80% · R 75% · Case 50%" ili "25%".
    var detailText: String {
        var parts: [String] = []
        if left != nil || right != nil {
            if let l = left { parts.append(L("detail.left", l)) }
            if let r = right { parts.append(L("detail.right", r)) }
        } else if let main = level {
            parts.append("\(main)%")
        }
        if let c = caseLevel { parts.append(L("detail.case", c)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    var normalizedName: String { BatteryDevice.normalize(name) }

    static func normalize(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func normalizeAddress(_ value: String?) -> String? {
        guard let value else { return nil }
        let hex = value.lowercased().filter { $0.isHexDigit }
        return hex.count == 12 ? hex : nil
    }

    /// Da li dva zapisa (iz različitih izvora) opisuju isti fizički uređaj.
    func matches(_ other: BatteryDevice) -> Bool {
        if let a = address, let b = other.address, a == b { return true }
        let compatible = kind == other.kind || kind == .other || other.kind == .other
        guard compatible else { return false }
        let n1 = normalizedName
        let n2 = other.normalizedName
        if n1 == n2 { return true }
        guard min(n1.count, n2.count) >= 4 else { return false }
        // "Muhamed's AirPods Pro" (system_profiler) == "AirPods Pro" (BLE)
        return n1.contains(n2) || n2.contains(n1)
    }

    /// Spaja podatke iz drugog izvora — zadržava postojeće vrednosti, popunjava prazne.
    mutating func absorb(_ other: BatteryDevice) {
        if other.name.count > name.count { name = other.name }
        if address == nil { address = other.address }
        if kind == .other { kind = other.kind }
        if level == nil { level = other.level }
        if left == nil { left = other.left }
        if right == nil { right = other.right }
        if caseLevel == nil { caseLevel = other.caseLevel }
        for source in other.sources where !sources.contains(source) {
            sources.append(source)
        }
    }

    /// Spaja liste iz više izvora (redosled = prioritet) i sortira za prikaz.
    /// `kindHints` (normalizovano ime → vrsta) popunjava vrstu uređajima koje nijedan izvor nije prepoznao.
    static func merge(_ lists: [[BatteryDevice]], kindHints: [String: DeviceKind] = [:]) -> [BatteryDevice] {
        var merged: [BatteryDevice] = []
        for list in lists {
            for device in list {
                if let index = merged.firstIndex(where: { $0.matches(device) }) {
                    merged[index].absorb(device)
                } else {
                    merged.append(device)
                }
            }
        }
        for index in merged.indices where merged[index].kind == .other {
            if let hint = kindHints[merged[index].normalizedName] { merged[index].kind = hint }
        }
        return merged.sorted { lhs, rhs in
            if lhs.kind.sortOrder != rhs.kind.sortOrder { return lhs.kind.sortOrder < rhs.kind.sortOrder }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
