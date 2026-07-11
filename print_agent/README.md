# God of Flutter Printer — Print Hub (`print_agent`)

**Print Hub** is a Windows desktop service that lets **web POS apps (Chrome)** print to USB, Bluetooth, and network printers on the shop counter PC.

Browsers cannot access USB/Bluetooth directly — Print Hub bridges that gap.

---

## For shop owners (install)

1. Download **`PrintWorkerHub-win64.zip`** from [GitHub Releases](https://github.com/bala-404/god_of_flutter_printer/releases)
2. Unzip on the counter PC
3. Right-click **`install_hub.bat`** → **Run as administrator**
4. Copy the LAN URL shown (e.g. `http://192.168.1.10:9280`)
5. Paste into your web POS printer settings as `hubUrl`

The hub auto-starts on every Windows boot.

**Uninstall:** Run `uninstall_service.ps1` as Administrator.

---

## For developers (build the zip)

### Quick build

```powershell
cd print_agent
.\scripts\package_release.ps1
```

Output: `print_agent/dist/PrintWorkerHub-win64.zip`

### Full release (tests + zip)

```powershell
cd tools
.\release_all.ps1
```

---

## Web app JSON

```json
"printer": {
  "printerName": "Rugtek Printer",
  "hubUrl": "http://192.168.1.10:9280"
}
```

Probe from Flutter web:

```dart
final probe = await PrintWorker.instance.probePrintAgent(
  'http://192.168.1.10:9280',
  discover: true,
);
```

---

## Distribution

| Channel | How |
|---------|-----|
| **GitHub Releases** | Attach `PrintWorkerHub-win64.zip` to each version tag |
| **Direct download** | Link to release asset in your docs / POS admin UI |
| **pub.dev** | Not published — this is an executable app, not a library |

---

## Files after install

| Path | Purpose |
|------|---------|
| `C:\ProgramData\PrintWorkerHub\hub-url.txt` | Saved hub URL |
| Desktop shortcut **Print Worker Hub** | Opens hub status |
| Scheduled Task `PrintWorkerHub` | Auto-start on boot |

Default port: **9280**

---

## Author

**Balamurugan** · AI Architect · Chennai, India  
Email: messagetobalamurugan@gmail.com · WhatsApp: [+91 75388 86343](https://wa.me/917538886343)  
Custom Print Hub deployments: contact for enterprise setup.
