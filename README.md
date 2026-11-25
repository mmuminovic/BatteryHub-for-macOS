# 🔋 Battery Hub

macOS menu bar aplikacija koja prikazuje bateriju svih tvojih povezanih Bluetooth uređaja:

```
🎧 14%   🖱 25%   ⌨️ 10%
```

- **Raširen prikaz** (podrazumevano pri svakom pokretanju): ikonica + procenat za svaki uređaj.
- **Skupljen prikaz**: jedna ikonica baterije koja pokazuje najslabiji uređaj.
- **Crveno** kad je uređaj na 20% ili manje.
- AirPods: u menu baru slabija slušalica, u meniju L / D / kutija posebno.
- Jezici: engleski (osnovni), srpski, bosanski, hrvatski — prati jezik sistema.

Zahteva macOS 13 Ventura ili noviji. Sandboxovana je i spremna za Mac App Store.

## Pokretanje

Treba ti Xcode i [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
./build.sh            # Release build u build/DerivedData i pokreni ga
./build.sh install    # isto, ali instalira u /Applications (preporučeno)
./build.sh demo       # Debug build sa izmišljenim uređajima (za screenshotove)
```

Prvi put će macOS pitati za **Bluetooth dozvolu** → klikni **Allow / Dozvoli**.
(Ako je slučajno odbiješ: meni nudi stavku koja otvara System Settings → Privacy & Security → Bluetooth.)

`project.yml` je izvor istine za Xcode projekat. Posle dodavanja fajlova ili promene podešavanja:
`xcodegen generate` (ručne izmene u Xcode-u se gube pri sledećem generisanju).

## Korišćenje

| Akcija | Šta radi |
|---|---|
| Klik na ikonicu | Meni sa svim uređajima i detaljima |
| **⌥ Option + klik** | Odmah skupi / raširi prikaz u menu baru |
| Meni → Skupi / Raširi u menu baru | Isto kao ⌥-klik |
| Meni → Osveži sada | Ručno osvežavanje (inače na 60 s + pri povezivanju uređaja) |
| Meni → Pokreni pri prijavi | Automatski start kad se uloguješ |
| Hover preko ikonica | Tooltip sa imenima i procentima |

## Odakle dolaze podaci

Aplikacija kombinuje četiri izvora i spaja duplikate:

1. **IOKit** — Apple Magic Keyboard / Mouse / Trackpad (bez dozvole)
2. **system_profiler** — AirPods, Beats, i slušalice drugih proizvođača za koje macOS zna bateriju
3. **IOBluetooth** — ostali povezani klasični Bluetooth uređaji (tek posle Bluetooth dozvole)
4. **BLE Battery Service** — Logitech MX i drugi Bluetooth Low Energy uređaji

Ako uređaj uopšte ne šalje nivo baterije preko Bluetooth-a (neke jeftinije slušalice, ili Logitech
preko Bolt/Unifying USB prijemnika umesto Bluetooth-a), pojaviće se u meniju sa „—", ali ne i u menu baru.

## Prilagođavanje

- Prag za crveno: `BatteryDevice.lowThreshold` u `Sources/BatteryDevice.swift`
- Interval osvežavanja: `BatteryMonitor.refreshInterval` u `Sources/BatteryMonitor.swift`
- Redosled i ikonice: `DeviceKind.sortOrder` / `symbolNames` u `Sources/BatteryDevice.swift`
- Tekstovi: `Resources/<jezik>.lproj/Localizable.strings`

## Debug argumenti (samo Debug build)

| Argument | Šta radi |
|---|---|
| `-DemoDevices` | Izmišljeni uređaji (AirPods Pro, Magic Keyboard na 14%…) umesto pravih — bez Bluetooth-a |
| `-OpenMenu` | Otvori meni 1,5 s posle pokretanja |
| `-ExportStatusItem` | Iscrta menu bar prikaz na 4x i pošalje PNG kao base64 na stderr (`EXPORT <ime> <base64>`) |
| `-DumpSources` | Ispiše na stderr šta je koji izvor pročitao |

## Mac App Store

Sve za App Store je u `AppStore/`:

- `AppStore/metadata.md` — naziv, podnaslov, opis, ključne reči, privatnost, napomene za review (EN + HR)
- `AppStore/screenshots/` — 5 screenshotova 2880 × 1800 (+ 1440 × 900)
- `AppStore/icon/` — vektorski master ikonice (SVG + VectorCraft) i 1024 PNG

Objava nove verzije:

1. U `project.yml` podigni `CURRENT_PROJECT_VERSION` (svaki upload) i `MARKETING_VERSION` (svaka verzija).
2. `scripts/release-appstore.sh` — arhivira i šalje build u App Store Connect
   (`--export-only` samo napravi `dist/appstore-export/Battery Hub.pkg`).

Potpisivanje je automatsko (cloud-managed Apple Distribution, tim 39KMKDXSBT), Xcode mora biti ulogovan.
Bundle ID: `com.mmuminovic.batteryhub`.
