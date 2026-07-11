/// How the developer targets a printer (platform-agnostic).
enum PrintConnectionKind {
  usb,
  bluetooth,
  network,
}

/// Printer endpoint for one job — each order/item can target a different printer.
class PrintTarget {
  const PrintTarget._({
    required this.kind,
    this.printerName,
    this.address,
    this.host,
    this.port = 9100,
    this.brand,
  });

  const PrintTarget.usb({
    required String printerName,
    String? brand,
  }) : this._(
          kind: PrintConnectionKind.usb,
          printerName: printerName,
          brand: brand,
        );

  const PrintTarget.bluetooth({
    required String address,
    String? brand,
  }) : this._(
          kind: PrintConnectionKind.bluetooth,
          address: address,
          brand: brand,
        );

  const PrintTarget.network({
    required String host,
    int port = 9100,
    String? brand,
  }) : this._(
          kind: PrintConnectionKind.network,
          host: host,
          port: port,
          brand: brand,
        );

  final PrintConnectionKind kind;
  final String? printerName;
  final String? address;
  final String? host;
  final int port;

  /// Optional label (e.g. Rugtek, Epson, Zebra) — for logs and your own routing.
  final String? brand;

  Map<String, dynamic> toMap() => {
        'type': kind.name,
        if (brand != null) 'brand': brand,
        ...switch (kind) {
          PrintConnectionKind.usb => {'printerName': printerName},
          PrintConnectionKind.bluetooth => {'address': address},
          PrintConnectionKind.network => {
              'host': host,
              if (port != 9100) 'port': port,
            },
        },
      };

  static PrintTarget? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;

    final type = (map['type'] ??
            map['connectionType'] ??
            map['connection_type'] ??
            map['transport'])
        ?.toString()
        .toLowerCase();

    final brand = map['brand']?.toString();

    return switch (type) {
      'usb' => PrintTarget.usb(
          printerName: map['printerName']?.toString() ?? '',
          brand: brand,
        ),
      'bluetooth' || 'bt' => PrintTarget.bluetooth(
          address: map['address']?.toString() ?? '',
          brand: brand,
        ),
      'network' || 'ip' || 'tcp' => PrintTarget.network(
          host: map['host']?.toString() ?? map['ip']?.toString() ?? '',
          port: _readPort(map['port']),
          brand: brand,
        ),
      _ => null,
    };
  }

  /// Parses connection from a job map (nested `connection` or flat root fields).
  static PrintTarget? fromJobMap(Map<String, dynamic> map) {
    final nested = map['connection'];
    if (nested is Map) {
      return fromMap(Map<String, dynamic>.from(nested));
    }

    final connectionType = map['connectionType'] ??
        map['connection_type'] ??
        map['transport'];
    if (connectionType == null) {
      return null;
    }

    return fromMap({
      'type': connectionType,
      'printerName': map['printerName'],
      'address': map['address'],
      'host': map['host'] ?? map['ip'],
      'port': map['port'],
      'brand': map['brand'],
    });
  }

  static int _readPort(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 9100;
  }
}
