import Foundation

/// Lokalizovan tekst iz Localizable.strings (en je osnovni jezik; sr, bs, hr prevodi).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Lokalizovan format string, npr. L("menu.updated", time).
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), locale: .current, arguments: args)
}
