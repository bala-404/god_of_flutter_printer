# God of Flutter Printer — Developer guide

How to integrate `god_of_flutter_printer` into a POS / billing app.  
**One JSON body per print job** from your database. The package validates, routes by platform, and prints.

---

## Table of contents

1. [Architecture](#architecture)
2. [Add dependency](#add-dependency)
3. [Unified JSON schema](#unified-json-schema)
4. [Print API](#print-api)
5. [Platform resolution](#platform-resolution)
6. [Connection fields](#connection-fields)
7. [Content types](#content-types)
8. [Validation (fail fast)](#validation-fail-fast)
9. [Web: Print Hub setup](#web-print-hub-setup)
10. [Windows native](#windows-native)
11. [Android native](#android-native)
12. [iOS native](#ios-native)
13. [Discover printers (optional)](#discover-printers-optional)
14. [Multi-printer / multi-user POS](#multi-printer--multi-user-pos)
15. [Advanced: PrintRequest API](#advanced-printrequest-api)
16. [Troubleshooting](#troubleshooting)
17. [HTML guide](#html-guide)

---

## Architecture

```
Your DB / API
     │
     ▼
 PrintJobBody (JSON)  ──►  PrintJobResolver  ──►  platform path
     │                         │
     │                         ├─ Web     → Print Hub → USB / BT / TCP
     │                         └─ Native  → direct USB / BT / TCP
     ▼
 PrintJobValidator (sync, instant)
     ▼
 PayloadEncoder (template / text / Tamil raster)
     ▼
 PrintWorker → job result
```

- **No global printer config** in the package.
- Each job carries its own `printer` block from your DB.
- Invalid jobs fail **before** any network or native I/O.

---

## Add dependency

```yaml
# pubspec.yaml
dependencies:
  god_of_flutter_printer:
    path: ../god_of_flutter_printer
```

```dart
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';
```

---

## Unified JSON schema

Every job uses the **same keys**. Unused values are empty (`""`, `{}`, `0`).

```json
{
  "jobId": "",
  "type": "template",
  "templateId": "tamil_check_80",
  "data": {
    "orderId": "TA-1001",
    "shopName": "அகம கடை",
    "total": "200.00"
  },
  "text": "",
  "document": {},
  "bytes": "",
  "printer": {
    "connectionType": "",
    "brand": "Rugtek",
    "printerName": "Rugtek Printer",
    "ip": "192.168.1.50",
    "port": 9100,
    "address": "",
    "hubUrl": "http://192.168.1.10:9280"
  },
  "protocol": "escPos",
  "paperWidthMm": 80,
  "charset": "",
  "options": {
    "timeoutMs": 15000,
    "retries": 1,
    "prependInit": true,
    "allowRasterFallback": true
  }
}
```

### Empty template (copy for new jobs)

```dart
final empty = PrintJobBody.emptyTemplate().toMap();
```

### Field reference

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | `template`, `text`, `document`, `raw` |
| `templateId` | For template | Built-in or your template id |
| `data` | For template | Template variables |
| `text` | For text | Plain text to print |
| `document` | For document | Block JSON layout |
| `bytes` | For raw | Base64 ESC/POS bytes |
| `printer` | Yes | Printer row from your DB (see below) |
| `protocol` | No | `escPos` (default), `tspl`, `zpl` |
| `paperWidthMm` | No | `58`, `72`, `80`, or `100` (default `80`) |
| `jobId` | No | Your id for logs |

---

## Print API

### 1. From DB map (most common)

```dart
Future<void> printOrder(Map<String, dynamic> dbRow) async {
  final result = await PrintWorker.instance.printFromMap(dbRow);

  if (result.failedInstantly) {
    throw Exception(result.errorMessage);
  }
  if (!result.isSuccess) {
    throw Exception(result.errorMessage ?? 'Print failed');
  }
}
```

### 2. Typed body

```dart
final body = PrintJobBody.fromMap(jsonDecode(dbString));
final result = await PrintWorker.instance.printBody(body);
```

### 3. Validate only (forms / API)

```dart
final spec = PrintJobSpec.fromMap(map);
final check = PrintWorker.instance.validateJob(spec);
if (!check.isValid) {
  return check.errors; // List<PrintJobFieldError>
}
```

### 4. Fire-and-forget

```dart
final result = await PrintWorker.instance.submitPrintJob(spec);
if (result.isQueued) {
  print('Job id: ${result.jobId}');
}
```

### Result handling

```dart
class PrintJobResult {
  bool failedInstantly;   // true = validation failed, no I/O
  bool isValidationFailure;
  bool isSuccess;
  bool isQueued;
  String? errorMessage;
  int bytesSent;
  List<PrintJobFieldError> validationErrors;
}
```

---

## Platform resolution

Same `printer` object from DB — different behaviour:

### When `connectionType` is empty (auto-detect)

| Priority | Web (Chrome) | Windows / Android / iOS |
|----------|--------------|-------------------------|
| 1 | `printerName` set → **USB via Hub** | `ip` set → **direct TCP** |
| 2 | `ip` set → **network via Hub** | `address` set → **Bluetooth** |
| 3 | `address` set → **BT via Hub** | `printerName` set → **USB** |

### Example: counter USB on web, IP on Windows

DB printer row:

```json
{
  "printerName": "Rugtek Printer",
  "ip": "192.168.1.50",
  "hubUrl": "http://192.168.1.10:9280",
  "brand": "Rugtek"
}
```

- **Web cashier** → Hub + USB name `Rugtek Printer`
- **Windows POS** → TCP `192.168.1.50:9100` (ignores `hubUrl`)

### Explicit override

Set `printer.connectionType` to force method:

- `usb`
- `network` (or `ip`, `tcp`)
- `bluetooth` (or `bt`)

---

## Connection fields

All keys live under `printer` (unused = `""`).

| Field | Used for | Example |
|-------|----------|---------|
| `connectionType` | Optional override | `""`, `usb`, `network`, `bluetooth` |
| `brand` | Label / logs only | `Rugtek`, `Epson` |
| `printerName` | USB (Windows spooler name) | `Rugtek Printer` |
| `ip` | Network printer | `192.168.1.50` |
| `port` | Network port | `9100` |
| `address` | Bluetooth MAC (Win/Android) or BLE UUID (iOS) | `60:6e:41:c8:0e:ad` or `A1B2C3D4-...` |
| `hubUrl` | **Web only** — Print Hub | `http://192.168.1.10:9280` |

On native apps, `hubUrl` in JSON is **ignored** (safe to keep in DB for web users).

---

## Content types

### Template

```dart
await PrintWorker.instance.printFromMap({
  'type': 'template',
  'templateId': 'kitchen_kot_80',
  'data': {
    'shopName': 'SLEEK BILL',
    'shopAddress': 'Nirmal Vijay, Panchshil Square, Tapovan Road, Camp, Amravati, 444602, IN',
    'phone': '+911234567890',
    'gstin': '27AAFCV2449G1Z7',
    'billNo': 'IN-15',
    'date': '23 - Jan - 2025',
    'time': '10:30 AM',
    'biller': 'John (B001)',
    'items': [
      {'name': 'Orange Powder', 'qty': '1', 'price': '400.00', 'amount': '448.00'},
      {'name': 'Walnuts 5% Tax Item', 'qty': '1', 'price': '200.00', 'amount': '210.00'},
      {'name': 'Peanuts 12% Tax Item', 'qty': '1', 'price': '100.00', 'amount': '112.00'},
      {'name': 'Almonds 18% Tax Item', 'qty': '1', 'price': '100.00', 'amount': '118.00'},
      {'name': 'Cashews 28% Tax Item', 'qty': '1', 'price': '50.00', 'amount': '64.00'},
      {'name': 'Pistachios 0% Tax Item', 'qty': '1', 'price': '50.00', 'amount': '50.00'},
    ],
    'subtotalQty': '6',
    'subtotalTax': '68.00',
    'subtotalAmt': '900.00',
    'taxes': [
      {'label': 'IGST at 0%', 'amount': '0.00'},
      {'label': 'IGST at 3%', 'amount': '3.00'},
      {'label': 'IGST at 5%', 'amount': '5.00'},
      {'label': 'IGST at 12%', 'amount': '60.00'},
    ],
    'total': '968.00',
    'advancePaid': '200.00',
    'balance': '768.00',
  },
  'printer': { /* from DB */ },
});
```

Built-in templates:

| ID | Use |
|----|-----|
| `tamil_check_80` | Tamil receipt |
| `kitchen_kot_80` | Kitchen ticket |
| `invoice_80` | Invoice |
| `day_close_80` | Day close report |

### Text (Tamil / Hindi / English)

```dart
await PrintWorker.instance.printFromMap({
  'type': 'text',
  'text': 'வணக்கம்\nBill #1024',
  'printer': { /* from DB */ },
  'options': {'allowRasterFallback': true},
});
```

### Raw ESC/POS

```dart
await PrintWorker.instance.printFromMap({
  'type': 'raw',
  'bytes': base64Encode(escPosBytes),
  'printer': { /* from DB */ },
});
```

---

## Validation (fail fast)

Validation is **synchronous** — no spinner, no timeout.

| Error field | Cause |
|-------------|--------|
| `templateId` | Empty on template job |
| `text` | Empty on text job |
| `connection.printerName` | USB selected but name empty |
| `connection.host` | Network selected but `ip` empty |
| `connection.address` | Invalid or missing MAC / UUID |
| `connection.type` | USB on iOS (not supported) |
| `hubUrl` | Missing on web |

```dart
final result = await PrintWorker.instance.printFromMap(badMap);
if (result.failedInstantly) {
  // e.g. "connection.host: host (IP address) is required for network printing"
  debugPrint(result.errorMessage);
}
```

---

## Web: Print Hub setup

Browsers cannot access USB or Bluetooth. Install **Print Hub** on the counter PC.

### Developer (build once)

```powershell
cd print_agent
.\scripts\package_release.ps1
```

Output: `print_agent/dist/PrintWorkerHub-win64.zip`

### Shop (install once per PC)

1. Unzip the zip on the counter PC.
2. Right-click `install_hub.bat` → **Run as administrator**.
3. Copy LAN URL from desktop shortcut **Print Worker Hub** or  
   `C:\ProgramData\PrintWorkerHub\hub-url.txt`.

### Web app JSON

Put the LAN URL in every web job:

```json
"printer": {
  "printerName": "Rugtek Printer",
  "ip": "",
  "hubUrl": "http://192.168.1.10:9280"
}
```

### Probe hub (settings screen)

```dart
final probe = await PrintWorker.instance.probePrintAgent(
  'http://192.168.1.10:9280',
  discover: true,
);
if (probe.online) {
  print(probe.printers); // USB names on that PC
}
```

---

## Windows native

No Print Hub. Pass the same JSON; package uses `ip` or `printerName` directly.

```powershell
cd example
flutter run -d windows
```

### USB

- Install printer driver in Windows.
- Use exact spooler name in `printer.printerName`.

### Bluetooth

- Pair printer in **Settings → Bluetooth**.
- List devices:

```dart
final devices = await PrintWorker.instance.listBluetoothDevices();
```

- Put `address` in DB `printer.address`.

### Network

- Set `printer.ip` and `port` (default `9100`).

---

## Android native

No Print Hub. Pass the same JSON; package uses `ip`, `address`, or `printerName` directly.

### USB

- Connect printer via USB OTG cable.
- Approve USB permission when Android prompts.
- List devices:

```dart
final printers = await PrintWorker.instance.listUsbPrinters();
// e.g. ["Rugtek [1234]"]
```

- Use the full name (with product ID) in `printer.printerName`.

### Bluetooth Classic

- **Pair first** in Android **Settings → Bluetooth**.
- List bonded devices:

```dart
final devices = await PrintWorker.instance.listBluetoothDevices();
```

- Put MAC address in DB `printer.address` (e.g. `60:6e:41:c8:0e:ad`).

### Network

- Set `printer.ip` and `port` (default `9100`).

### Permissions

Ensure your app has Bluetooth permissions in `AndroidManifest.xml` (the plugin requests them at runtime).

---

## iOS native

No Print Hub. iOS does **not** support USB printing or Bluetooth Classic (SPP). Use **BLE thermal printers** or **network (TCP)**.

### Info.plist

Add Bluetooth usage description:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to connect to receipt printers.</string>
```

### BLE printer setup

1. Turn on the BLE thermal printer.
2. List nearby BLE devices:

```dart
final devices = await PrintWorker.instance.listBluetoothDevices();
for (final d in devices) {
  print('${d.name} — ${d.address}'); // address is a UUID on iOS
}
```

3. Store the device **UUID** in `printer.address` (not a MAC address).
4. Example: `A1B2C3D4-E5F6-7890-ABCD-EF1234567890`

### Network

- Set `printer.ip` and `port` (default `9100`) — same as other platforms.

### Run on device

```bash
cd example
flutter run -d <ios-device-id>
```

---

## Discover printers (optional)

Use in a **settings / admin** screen to help users pick printers.  
Production print jobs still use DB JSON — no global config in the package.

```dart
// Windows USB names
final usb = await PrintWorker.instance.listUsbPrinters();

// Bluetooth paired devices (native)
final bt = await PrintWorker.instance.listBluetoothDevices();

// Web: via hub
final btWeb = await PrintWorker.instance.listBluetoothDevices(
  agentBaseUrl: hubUrl,
);
```

---

## Multi-printer / multi-user POS

Each order line or station can point to a different printer row from DB:

```dart
for (final line in order.lines) {
  final printerRow = await db.printer(line.printerId);
  final job = {
    'type': 'template',
    'templateId': line.templateId,
    'data': line.templateData,
    'printer': printerRow.toJson(), // same schema every time
    'paperWidthMm': printerRow.paperWidth,
  };
  await PrintWorker.instance.printFromMap(job);
}
```

Kitchen → network IP. Counter → USB name + hub on web. Back office → Windows TCP.  
**Same schema**, different filled fields.

---

## Advanced: PrintRequest API

Lower-level control (optional):

```dart
await PrintWorker.instance.execute(
  PrintRequest(
    connection: PrintConnection.usb(deviceId: 'Rugtek Printer'),
    protocol: PrintProtocol.escPos,
    paperWidthMm: 80,
    mode: PrintMode.text,
    payload: PrintPayload.text('Hello'),
  ),
);
```

Prefer `printFromMap` for DB-driven POS apps.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `failedInstantly` + field error | Missing JSON field | Fix DB row / form |
| Web: hub offline | Print Hub not running | Install / start hub on counter PC |
| Web: BT timeout | Hub ran as SYSTEM | Reinstall hub (`install_hub.bat`) |
| Windows: USB list empty | Driver / plugin | Install driver; run native app |
| Windows: BT fail | Not paired | Pair in Settings, refresh address |
| Android: BT fail | Not paired | Pair in Android Settings → Bluetooth |
| Android: USB fail | No permission | Reconnect printer; approve USB prompt |
| iOS: no printers | BLE scan empty | Turn printer on; enable Bluetooth; refresh |
| iOS: USB error | Platform limitation | Use BLE or network instead |
| iOS: invalid address | MAC instead of UUID | Use BLE UUID from `listBluetoothDevices()` |
| Job completed, no paper | Driver error in Windows | Fix printer queue in Settings |
| Tamil boxes | Raster off | `allowRasterFallback: true` |

---

## Related docs

- [README.md](../README.md) — package overview
- [index.html](index.html) — **full HTML guide** (open in browser)
- [print_agent/README.md](../../print_agent/README.md) — Print Hub
- [example/README.md](../../example/README.md) — demo app

---

## HTML guide

For a browsable version of this documentation with navigation and platform matrix:

**[Open docs/index.html](index.html)** in any web browser.

From terminal (macOS):

```bash
open god_of_flutter_printer/doc/index.html
```
