# God of Flutter Printer — Example Demo App

Interactive demo for **USB**, **Bluetooth/BLE**, **network TCP**, and **web Print Hub** printing.

Try every platform feature before integrating into your POS app.

---

## Run the demo

### From pub.dev (after you publish)

```yaml
# Clone the repo — example uses path dependency during development
```

### From this monorepo (local)

```bash
cd example
flutter pub get
```

| Platform | Command |
|----------|---------|
| **Windows** | `flutter run -d windows` |
| **Chrome (web)** | `flutter run -d chrome` |
| **Android** | `flutter run -d <device>` |
| **iOS** | `flutter run -d <device>` |

Web demo script (Windows):
```powershell
.\scripts\run_web.ps1
```

---

## What the demo shows

- Platform-specific connection options (USB / BT / network / Print Hub)
- Live JSON payload preview sent to `PrintWorker`
- Template printing (`tamil_check_80`, `kitchen_kot_80`, etc.)
- Print Hub download / build helper (Developer tab on Windows)

---

## Distribution

The example app is **not published to pub.dev** — it ships with the GitHub repo.

**For users:**
1. Clone: `git clone https://github.com/bala-404/god_of_flutter_printer`
2. `cd god_of_flutter_printer/example`
3. `flutter pub get && flutter run`

**For you (releases):**
- Tag a GitHub release with source code
- Point users to the `example/` folder in the README

---

## Dependencies

Uses local path to the main package during development:

```yaml
god_of_flutter_printer:
  path: ../god_of_flutter_printer
```

After pub.dev publish, you can switch to:

```yaml
god_of_flutter_printer: ^0.1.0
```

---

## Author

**Balamurugan** · AI Architect · Chennai, India  
Email: messagetobalamurugan@gmail.com · WhatsApp: [+91 75388 86343](https://wa.me/917538886343)
