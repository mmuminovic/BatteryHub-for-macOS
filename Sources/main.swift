import AppKit

// Battery Hub — menu bar aplikacija koja prikazuje bateriju Bluetooth uređaja.
// Nema Dock ikonicu (LSUIElement + .accessory), živi samo u menu baru.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
