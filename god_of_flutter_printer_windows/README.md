# god_of_flutter_printer_windows

[![pub package](https://img.shields.io/pub/v/god_of_flutter_printer_windows.svg)](https://pub.dev/packages/god_of_flutter_printer_windows)

**Windows native plugin** for [God of Flutter Printer](https://pub.dev/packages/god_of_flutter_printer) — USB spooler and Bluetooth Classic (SPP) printing on Windows desktop.

Built with C++ for the Windows print spooler and Win32 Bluetooth APIs. Registered automatically when you depend on `god_of_flutter_printer` on Windows.

> **Do not import this package directly in your app.**  
> Add [`god_of_flutter_printer`](https://pub.dev/packages/god_of_flutter_printer) to your `pubspec.yaml` instead. This plugin is installed automatically on Windows.

---

## Features

| Feature | Description |
|---------|-------------|
| **USB / spooler** | Send raw ESC/POS (or other) bytes to any Windows-installed printer |
| **Bluetooth Classic** | SPP printing to paired thermal printers |
| **Printer discovery** | `listUsbPrinters()` and Bluetooth device listing via platform channel |
| **Zero config** | Auto-registers as the Windows implementation of `god_of_flutter_printer` |

### Native implementation

| File | Purpose |
|------|---------|
| `usb_spool_printer.cpp` | Raw spooler writes via Win32 API |
| `bluetooth_spp_printer.cpp` | Bluetooth Classic socket printing |
| `print_worker_windows_plugin.cpp` | Flutter plugin method channel |

---

## Install (app developers)

```yaml
dependencies:
  god_of_flutter_printer: ^0.1.1
```

Run on Windows:

```bash
flutter run -d windows
```

USB and Bluetooth printing work through `PrintWorker.instance` from the main package — no extra Windows setup in Dart code.

---

## Example

See the monorepo demo app:

```bash
git clone https://github.com/bala-404/god_of_flutter_printer
cd god_of_flutter_printer/example
flutter run -d windows
```

Plugin-only example: `example/` folder in this package.

---

## Monorepo structure

| Package | Role |
|---------|------|
| [`god_of_flutter_printer`](https://pub.dev/packages/god_of_flutter_printer) | Main API — `PrintWorker`, templates, encoders |
| [`god_of_flutter_printer_platform_interface`](https://pub.dev/packages/god_of_flutter_printer_platform_interface) | Platform interface |
| **`god_of_flutter_printer_windows`** (this package) | Windows native implementation |

Source code: [github.com/bala-404/god_of_flutter_printer](https://github.com/bala-404/god_of_flutter_printer)

---

## Requirements

- Flutter **≥ 3.24.0**
- Dart SDK **^3.5.0**
- Windows 10 or later
- For Bluetooth: printer paired in Windows Settings before printing

---

## Author

**Balamurugan** · AI Architect · Chennai, India

| | |
|---|---|
| **Email** | [messagetobalamurugan@gmail.com](mailto:messagetobalamurugan@gmail.com) |
| **WhatsApp** | [+91 75388 86343](https://wa.me/917538886343) |
| **Publisher** | [wallei.in](https://pub.dev/publishers/wallei.in) |
| **Custom solutions** | Enterprise POS printing, Tamil/Hindi receipts, Print Hub setup, multi-printer Windows deployments |

Need help deploying printers on counter PCs or building a custom POS? **Connect on WhatsApp or email.**

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
