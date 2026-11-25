# Battery Hub — App Store Connect metadata

Everything to paste into App Store Connect. Character limits are checked.

## App record (My Apps → + → New App)

| Field | Value |
|---|---|
| Platform | macOS |
| Name | **Battery Hub: Bluetooth Battery** (30/30). If taken, use **Battery Hub – Device Battery** (28) or **Battery Hub for Mac** (19) |
| Primary language | English (U.S.) |
| Bundle ID | `com.mmuminovic.batteryhub` (already registered on team 39KMKDXSBT by Xcode) |
| SKU | `batteryhub-mac-001` |
| User access | Full access |

## App Information

| Field | Value |
|---|---|
| Subtitle (30) | `AirPods, mouse & keyboard %` (27) |
| Category | Primary: **Utilities** · Secondary: **Productivity** |
| Content rights | Does not contain, show or access third-party content |
| Age rating | Answer **None / No** to everything → **4+** |
| Privacy Policy URL | `https://github.com/mmuminovic/privacy-policies/blob/main/battery-hub/privacy-policy.md` (after you push the privacy-policies repo, see README) |

## Pricing and availability

Your choice. Suggested: **Free** (or a one-time price tier such as $2.99). All countries.

## App Privacy (nutrition label)

- Data collection: **"No, we do not collect data from this app"**.
- Tracking: none.

## Version 1.0.0 — English (U.S.)

**Promotional text (170)**

```
See the battery of your AirPods, mouse, keyboard and trackpad side by side in the menu bar. Low devices turn red, so nothing dies on you mid-call.
```

**Description (4000)**

```
Battery Hub puts the battery level of every connected Bluetooth device right in your menu bar, side by side:

🎧 79%   🖱 57%   ⌨️ 14%   🎮 68%

No more opening Control Center or Bluetooth settings to find out which device is about to die.

EVERY DEVICE AT A GLANCE
• AirPods and Beats: the weaker bud in the menu bar, and left, right and case separately in the menu
• Magic Keyboard, Magic Mouse and Magic Trackpad
• Headphones, mice, keyboards and game controllers that report their battery over Bluetooth
• Bluetooth Low Energy devices with the standard battery service, like many modern mice and keyboards

LOW BATTERY TURNS RED
Any device at 20% or less turns red in the menu bar, so you charge it before it dies in the middle of a call or a game.

COMPACT WHEN YOU NEED THE SPACE
Option-click the icon to collapse everything into a single battery icon that shows your weakest device. Option-click again to expand.

ALWAYS UP TO DATE
Battery Hub refreshes every minute, right after a device connects or disconnects, and when your Mac wakes up. Hover over the icons for a quick summary.

LIGHTWEIGHT AND NATIVE
• A tiny native Mac app, built for Apple silicon and Intel
• Lives only in the menu bar: no Dock icon, no windows
• Optional launch at login
• Works in light and dark mode

PRIVATE BY DESIGN
No account. No internet connection. No analytics, no ads, no tracking. Battery Hub only reads the battery levels of devices that are already connected to your Mac and never stores or sends them anywhere.

Note: a device appears with a battery level only if it reports its battery to macOS over Bluetooth. Devices connected through a USB receiver (for example some Logitech Unifying or Bolt receivers) do not share their battery over Bluetooth.

Requires macOS 13 Ventura or later.
```

**Keywords (100)** — no spaces after commas, no words already in the name

```
airpods,headphones,mouse,keyboard,trackpad,menubar,status,level,percent,charge,low,magic,devices
```

(96 characters)

**Support URL**: `https://github.com/mmuminovic/privacy-policies` (replace with a support page or a `mailto:`-style contact page if you have one; Apple requires a URL)

**Marketing URL**: optional, leave empty.

**Copyright**: `2026 Muhamed Muminovic`

**What's New**: not shown for the first version.

## Version 1.0.0 — Croatian (optional second localization)

App Store Connect has no Serbian or Bosnian; Croatian covers the region. The app itself is localized into English, Serbian, Bosnian and Croatian.

- **Subtitle**: `Baterije uređaja u izborniku` (28)
- **Promotional text**: `Baterija AirPodsa, miša, tipkovnice i trackpada jedna do druge u traci izbornika. Uređaji na 20 % ili manje postaju crveni.`
- **Keywords**: `baterija,slušalice,airpods,miš,tipkovnica,trackpad,bluetooth,izbornik,postotak,punjenje`
- **Description**:

```
Battery Hub prikazuje razinu baterije svih tvojih povezanih Bluetooth uređaja u traci izbornika, jedan do drugog:

🎧 79%   🖱 57%   ⌨️ 14%   🎮 68%

• AirPods i Beats: slabija slušalica u traci izbornika, a lijeva, desna i kutija posebno u izborniku
• Magic Keyboard, Magic Mouse i Magic Trackpad
• Slušalice, miševi, tipkovnice i kontroleri koji javljaju bateriju preko Bluetootha
• Bluetooth Low Energy uređaji sa standardnim servisom baterije

Uređaj na 20 % ili manje postaje crven. ⌥-klik na ikonu skuplja sve u jednu ikonu baterije koja pokazuje najslabiji uređaj.

Bez računa, bez interneta, bez praćenja. Aplikacija samo čita bateriju uređaja koji su već povezani s tvojim Macom i nikamo je ne šalje.

Potreban je macOS 13 Ventura ili noviji.
```

## App Review Information

- Sign-in required: **No**
- Contact: your name, phone and email
- **Notes** (paste as is):

```
Battery Hub is a menu bar app (LSUIElement): after launch it shows only an icon in the menu bar, there is no Dock icon and no window.

1. On first launch macOS asks for Bluetooth permission. Please click Allow. The app uses Bluetooth only to read the battery level of devices that are already connected to the Mac; it does not scan for, pair with or control devices.
2. Click the menu bar icon to see all connected Bluetooth devices with their battery levels (AirPods show left, right and case).
3. Option-click the icon to collapse the menu bar display into one battery icon (the weakest device); Option-click again to expand.

If the review Mac has no Bluetooth device with a battery connected (for example AirPods, a Magic Keyboard, Magic Mouse or Magic Trackpad), the menu shows "No connected devices" and the menu bar shows a single battery icon. Connecting any such device makes it appear within a few seconds.

The app does not use the network and collects no data.
```

## Screenshots

Mac, 16:10. Upload `AppStore/screenshots/batteryhub_mac_01.png` … `_05.png` (2880 × 1800) in order. The 1440 × 900 copies are there in case you prefer the smaller size.

## Build

`scripts/release-appstore.sh` uploads the build; then pick it under the version's **Build** section. Export compliance is already answered in Info.plist (`ITSAppUsesNonExemptEncryption = NO`).
