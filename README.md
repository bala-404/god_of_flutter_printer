# God of Flutter Printer

**Cross-platform Flutter thermal printing** — USB, Bluetooth/BLE, network TCP, and web via Print Hub.

Pub package name: **`god_of_flutter_printer`**

---

## Author & support

**Balamurugan** · AI Architect · Chennai, India

| Contact | |
|---------|---|
| Email | [messagetobalamurugan@gmail.com](mailto:messagetobalamurugan@gmail.com) |
| WhatsApp | [+91 75388 86343](https://wa.me/917538886343) |
| Custom solutions | Enterprise POS printing, Tamil/Hindi receipts, multi-printer setups |

**Buy me a coffee** — UPI: `balamuruganm2102-1@okaxis`

---

## Packages & distribution

| Folder | Ships via | Users get it |
|--------|-----------|--------------|
| [**god_of_flutter_printer**](god_of_flutter_printer/) | **pub.dev** | `god_of_flutter_printer: ^0.1.0` |
| [god_of_flutter_printer_windows](god_of_flutter_printer_windows/) | pub.dev (dependency) | Auto-installed |
| [god_of_flutter_printer_platform_interface](god_of_flutter_printer_platform_interface/) | pub.dev (dependency) | Auto-installed |
| [**example**](example/) | **GitHub repo** | Clone → `cd example` → `flutter run` |
| [**print_agent**](print_agent/) | **GitHub Releases** | Download `PrintWorkerHub-win64.zip` |
| [**tools**](tools/) | **GitHub repo** | Build scripts & font downloader |

**Full publish guide:** [PUBLISHING.md](PUBLISHING.md)

---

## Documentation

| Document | Contents |
|----------|----------|
| **[Full HTML guide](god_of_flutter_printer/doc/index.html)** | Complete mechanics — open in browser |
| [HOW_TO_USE.md](god_of_flutter_printer/doc/HOW_TO_USE.md) | Markdown integration guide |
| [god_of_flutter_printer/README.md](god_of_flutter_printer/README.md) | Package README for pub.dev |

```bash
open god_of_flutter_printer/doc/index.html
```

---

## Install

```yaml
dependencies:
  god_of_flutter_printer: ^0.1.0
```

```dart
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

final result = await PrintWorker.instance.printFromMap({
  'type': 'template',
  'templateId': 'tamil_check_80',
  'data': orderData,
  'printer': printerRowFromDb,
});
```

---

## Platform matrix

| Platform | USB | Bluetooth | Network | Web agent |
|----------|-----|-----------|---------|-----------|
| Windows | ✅ | Classic SPP | ✅ TCP | — |
| Android | ✅ OTG | Classic SPP | ✅ TCP | — |
| iOS | ❌ | ✅ BLE | ✅ TCP | — |
| Web | Via Hub | Via Hub | Via Hub | ✅ |

---

## Quick run

```bash
cd example && flutter run -d windows
cd example && flutter run -d chrome
cd god_of_flutter_printer && flutter test
```

---

## Publish to pub.dev

```bash
cd god_of_flutter_printer
dart pub publish --dry-run
```

---

## License

MIT — Copyright © 2026 Balamurugan, Chennai, India.
