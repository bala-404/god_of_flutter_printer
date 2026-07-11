# God of Flutter Printer

[![pub package](https://img.shields.io/pub/v/god_of_flutter_printer.svg)](https://pub.dev/packages/god_of_flutter_printer)

**Cross-platform thermal & label printing for Flutter POS apps** — ESC/POS, TSPL, ZPL on **Windows**, **Android**, **iOS**, and **Web**.

One JSON print job from your database → validate → route by platform → print. No printer registry inside the package.

---

## Author

**Balamurugan** · AI Architect · Chennai, India

| | |
|---|---|
| **Email** | [messagetobalamurugan@gmail.com](mailto:messagetobalamurugan@gmail.com) |
| **WhatsApp** | [+91 75388 86343](https://wa.me/917538886343) |
| **Custom solutions** | POS printing, multi-platform integrations, Tamil/Hindi receipts, Print Hub setup |

Need a custom printer integration, white-label POS printing, or enterprise deployment? **Connect on WhatsApp or email** — I build tailored Flutter printing solutions.

---

## Support this project

If God of Flutter Printer saved you time on your POS app, consider buying me a coffee:

| Method | Details |
|--------|---------|
| **UPI (India)** | `balamuruganm2102-1@okaxis` |
| **Buy Me a Coffee** | [buymeacoffee.com](https://www.buymeacoffee.com/) — search *Balamurugan* or use UPI above |

Your support helps maintain cross-platform printer drivers, BLE/iOS updates, and new template features.

---

## Documentation

| Guide | Link |
|-------|------|
| **Full HTML guide (all platforms)** | [doc/index.html](doc/index.html) — open in browser |
| Markdown integration guide | [doc/HOW_TO_USE.md](doc/HOW_TO_USE.md) |
| Monorepo overview | [../README.md](../README.md) |
| Print Hub (web) | [../print_agent/README.md](../print_agent/README.md) |

```bash
# Open HTML guide (macOS)
open doc/index.html
```

---

## Install

### From pub.dev (when published)

```yaml
dependencies:
  god_of_flutter_printer: ^0.1.1
```

### Local path (development)

```yaml
dependencies:
  god_of_flutter_printer:
    path: ../god_of_flutter_printer
```

```dart
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';
```

---

## Quick start

```dart
final result = await PrintWorker.instance.printFromMap({
  'type': 'template',
  'templateId': 'tamil_check_80',
  'data': {
    'orderId': 'TA-1001',
    'shopName': 'அகம கடை',
    'total': '200.00',
  },
  'printer': printerRowFromDb,
  'protocol': 'escPos',
  'paperWidthMm': 80,
});

if (result.failedInstantly) {
  showError(result.errorMessage);
} else if (result.isSuccess) {
  showOk('Printed ${result.bytesSent} bytes');
}
```

---

## Platforms

| Runtime | USB | Bluetooth | Network (TCP) | How |
|---------|-----|-----------|---------------|-----|
| **Windows** | Direct | Classic SPP | Direct | Native plugin |
| **Android** | USB OTG | Classic SPP (paired) | Direct | Native plugin |
| **iOS** | No | BLE | Direct | Native plugin |
| **Web (Chrome)** | Via Print Hub | Via Print Hub | Via Print Hub | `print_agent` |

- **Web** needs `printer.hubUrl` (Print Hub on counter PC).
- **Native** apps print directly — no agent.

Full platform setup: [doc/index.html#platforms](doc/index.html#platforms)

---

## API summary

| Method | Use |
|--------|-----|
| `printFromMap(map)` | **Primary** — JSON from DB/API |
| `printBody(PrintJobBody)` | Same, typed |
| `validateJob(spec)` | Instant validation, no I/O |
| `listUsbPrinters()` | USB discovery (Windows, Android) |
| `listBluetoothDevices()` | BT/BLE discovery |
| `probePrintAgent(url)` | Web — check Print Hub |

Full API: [doc/index.html#api](doc/index.html#api)

---

## Built-in templates

`tamil_check_80` · `kitchen_kot_80` · `invoice_80` · `day_close_80`

Tamil/Hindi: set `options.allowRasterFallback: true` (default).

---

## Example app

```bash
cd example
flutter run -d windows
flutter run -d chrome
flutter run -d <device>   # Android / iOS
```

---

## Publishing checklist (pub.dev)

```bash
cd god_of_flutter_printer
dart pub publish --dry-run
dart pub publish
```

Requires: `LICENSE`, `CHANGELOG.md`, `README.md`, valid `homepage` / `repository` URLs.

---

## License

**MIT License** — Copyright © 2026 **Balamurugan**, Chennai, India.

Permission is granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, subject to the following conditions:

- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Full license text: [LICENSE](LICENSE)  
Publisher: [wallei.in](https://pub.dev/publishers/wallei.in) · Repository: [GitHub](https://github.com/bala-404/god_of_flutter_printer)

---

<p align="center">
  Made with ❤️ in Chennai ·
  <a href="mailto:messagetobalamurugan@gmail.com">Email</a> ·
  <a href="https://wa.me/917538886343">WhatsApp</a> ·
  UPI: <code>balamuruganm2102-1@okaxis</code>
</p>
