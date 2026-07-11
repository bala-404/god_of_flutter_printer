/// A discoverable Bluetooth printer/end-point.
class BluetoothDeviceInfo {
  const BluetoothDeviceInfo({
    required this.name,
    required this.address,
    this.type = BluetoothTransportType.classic,
  });

  final String name;
  final String address;
  final BluetoothTransportType type;
}

enum BluetoothTransportType { classic, ble }
