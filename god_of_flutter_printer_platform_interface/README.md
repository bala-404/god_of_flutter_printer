# god_of_flutter_printer_platform_interface

[![pub package](https://img.shields.io/pub/v/god_of_flutter_printer_platform_interface.svg)](https://pub.dev/packages/god_of_flutter_printer_platform_interface)

**Platform interface** for [God of Flutter Printer](https://pub.dev/packages/god_of_flutter_printer) — the cross-platform Flutter package for thermal & label printing (ESC/POS, TSPL, ZPL).

This package defines the **native bridge contract** between Dart and platform-specific printer connectors on **Android**, **iOS**, and **Windows**.

> **Do not import this package directly in your app.**  
> Add [`god_of_flutter_printer`](https://pub.dev/packages/god_of_flutter_printer) to your `pubspec.yaml` instead. This package is installed automatically as a dependency.

---

## What this package provides

| Area | Description |
|------|-------------|
| **USB printing** | List USB printers and send raw bytes (Windows spooler, Android OTG) |
| **Bluetooth** | Discover paired/classic and BLE devices; connect and print |
| **Platform abstraction** | `PrintWorkerPlatform` — implemented by Android, iOS, and Windows plugins |
| **Shared models** | `BluetoothDeviceInfo`, transport types, connection metadata |

### Exported API (for plugin authors)

- `PrintWorkerPlatform` — platform channel contract
- `BluetoothDeviceInfo` — device name, address, transport type
- `BluetoothTransportType` — classic SPP vs BLE

End-user apps should use `PrintWorker` from the main package, not these low-level types.

---

## Install (app developers)

```yaml
dependencies:
  god_of_flutter_printer: ^0.1.1
```

This interface package is pulled in automatically. **Do not** add it manually unless you are writing a federated plugin implementation.

---

## Monorepo structure

| Package | Role |
|---------|------|
| [`god_of_flutter_printer`](https://pub.dev/packages/god_of_flutter_printer) | Main API — `PrintWorker`, templates, encoders |
| **`god_of_flutter_printer_platform_interface`** (this package) | Platform interface |
| [`god_of_flutter_printer_windows`](https://pub.dev/packages/god_of_flutter_printer_windows) | Windows native implementation |

Source code: [github.com/bala-404/god_of_flutter_printer](https://github.com/bala-404/god_of_flutter_printer)

---

## Author

**Balamurugan** · AI Architect · Chennai, India

| | |
|---|---|
| **Email** | [messagetobalamurugan@gmail.com](mailto:messagetobalamurugan@gmail.com) |
| **WhatsApp** | [+91 75388 86343](https://wa.me/917538886343) |
| **Publisher** | [wallei.in](https://pub.dev/publishers/wallei.in) |
| **Custom solutions** | Enterprise POS printing, Tamil/Hindi receipts, multi-printer setups, Print Hub deployment |

Need a custom printer integration or white-label POS printing? **Connect on WhatsApp or email.**

---

## Support this project

| Method | Details |
|--------|---------|
| **UPI (India)** | `balamuruganm2102-1@okaxis` |
| **GitHub** | [bala-404/god_of_flutter_printer](https://github.com/bala-404/god_of_flutter_printer) |

---

## License

**MIT License** — Copyright © 2026 **Balamurugan**, Chennai, India.

Permission is granted to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, subject to the conditions in the [LICENSE](LICENSE) file.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NONINFRINGEMENT.

Full license text: [LICENSE](LICENSE)

---

<p align="center">
  Part of <strong>God of Flutter Printer</strong> · Made with ❤️ in Chennai ·
  <a href="mailto:messagetobalamurugan@gmail.com">Email</a> ·
  <a href="https://wa.me/917538886343">WhatsApp</a>
</p>
