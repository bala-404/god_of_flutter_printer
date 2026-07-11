import CoreBluetooth
import Flutter

/// CoreBluetooth bridge for BLE thermal printers on iOS.
///
/// iOS does not expose Bluetooth Classic (SPP). The plugin maps both
/// `bluetooth*` and `ble*` method-channel calls to this manager.
final class BlePrinterManager: NSObject {
  private var centralManager: CBCentralManager!
  private var connectedPeripheral: CBPeripheral?
  private var writeCharacteristic: CBCharacteristic?

  private var pendingConnectResult: FlutterResult?
  private var pendingListResult: FlutterResult?
  private var pendingWriteResult: FlutterResult?
  private var pendingWriteData: Data?

  private var discoveredDevices: [String: [String: String]] = [:]
  private var scanTimer: Timer?
  private var connectTimeoutTimer: Timer?
  private var connectTargetAddress: String?

  private var readyCallbacks: [() -> Void] = []

  override init() {
    super.init()
    centralManager = CBCentralManager(delegate: self, queue: .main)
  }

  func listBluetoothDevices(result: @escaping FlutterResult) {
    runWhenPoweredOn {
      self.pendingListResult = result
      self.discoveredDevices.removeAll()
      self.centralManager.stopScan()

      // Include peripherals iOS already knows about (previously connected).
      let known = self.centralManager.retrieveConnectedPeripherals(withServices: [])
      for peripheral in known {
        self.recordPeripheral(peripheral)
      }

      self.centralManager.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
      )

      self.scanTimer?.invalidate()
      self.scanTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { [weak self] _ in
        self?.finishDeviceScan()
      }
    } onFailure: { message in
      result(FlutterError(code: "bluetooth_disabled", message: message, details: nil))
    }
  }

  func connect(address: String, timeoutMs: Int, result: @escaping FlutterResult) {
    let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      result(FlutterError(code: "invalid_args", message: "address is required", details: nil))
      return
    }

    runWhenPoweredOn {
      self.disconnectInternal()
      self.pendingConnectResult = result
      self.connectTargetAddress = trimmed.uppercased()

      if let uuid = UUID(uuidString: trimmed) {
        let retrieved = self.centralManager.retrievePeripherals(withIdentifiers: [uuid])
        if let peripheral = retrieved.first {
          self.connectToPeripheral(peripheral, timeoutMs: timeoutMs)
          return
        }
      }

      // Fall back to an active scan when the UUID is not cached yet.
      self.centralManager.stopScan()
      self.discoveredDevices.removeAll()
      self.centralManager.scanForPeripherals(
        withServices: nil,
        options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
      )

      self.connectTimeoutTimer?.invalidate()
      self.connectTimeoutTimer = Timer.scheduledTimer(
        withTimeInterval: TimeInterval(timeoutMs) / 1000.0,
        repeats: false
      ) { [weak self] _ in
        self?.failConnect("Bluetooth connection timed out. Ensure the printer is on and nearby.")
      }
    } onFailure: { message in
      result(FlutterError(code: "bluetooth_disabled", message: message, details: nil))
    }
  }

  func write(data: Data, result: @escaping FlutterResult) {
    guard !data.isEmpty else {
      result(FlutterError(code: "invalid_args", message: "data bytes are required", details: nil))
      return
    }
    guard let peripheral = connectedPeripheral,
          let characteristic = writeCharacteristic,
          peripheral.state == .connected else {
      result(FlutterError(code: "not_connected", message: "Bluetooth printer is not connected.", details: nil))
      return
    }

    pendingWriteResult = result
    pendingWriteData = data
    writeNextChunk(peripheral: peripheral, characteristic: characteristic)
  }

  func disconnect() {
    disconnectInternal()
  }

  // MARK: - Private helpers

  private func runWhenPoweredOn(
    _ action: @escaping () -> Void,
    onFailure: @escaping (String) -> Void
  ) {
    switch centralManager.state {
    case .poweredOn:
      action()
    case .unknown, .resetting:
      readyCallbacks.append(action)
    case .unsupported:
      onFailure("Bluetooth is not supported on this device.")
    case .unauthorized:
      onFailure("Bluetooth permission denied. Allow Bluetooth access for this app.")
    case .poweredOff:
      onFailure("Bluetooth is turned off. Enable Bluetooth and try again.")
    @unknown default:
      onFailure("Bluetooth is not available.")
    }
  }

  private func recordPeripheral(_ peripheral: CBPeripheral) {
    let address = peripheral.identifier.uuidString.uppercased()
    let rawName = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let name = rawName.isEmpty ? "Bluetooth device" : rawName
    discoveredDevices[address] = [
      "name": name,
      "address": address,
      "type": "ble",
    ]
  }

  private func finishDeviceScan() {
    centralManager.stopScan()
    scanTimer?.invalidate()
    scanTimer = nil

    let devices = discoveredDevices.values.sorted {
      ($0["name"] ?? "") < ($1["name"] ?? "")
    }
    pendingListResult?(devices)
    pendingListResult = nil
  }

  private func connectToPeripheral(_ peripheral: CBPeripheral, timeoutMs: Int) {
    connectedPeripheral = peripheral
    peripheral.delegate = self
    centralManager.connect(peripheral, options: nil)

    connectTimeoutTimer?.invalidate()
    connectTimeoutTimer = Timer.scheduledTimer(
      withTimeInterval: TimeInterval(timeoutMs) / 1000.0,
      repeats: false
    ) { [weak self] _ in
      self?.failConnect("Bluetooth connection timed out. Ensure the printer is on and nearby.")
    }
  }

  private func failConnect(_ message: String) {
    centralManager.stopScan()
    connectTimeoutTimer?.invalidate()
    connectTimeoutTimer = nil
    connectTargetAddress = nil

    if let peripheral = connectedPeripheral {
      centralManager.cancelPeripheralConnection(peripheral)
    }
    connectedPeripheral = nil
    writeCharacteristic = nil

    pendingConnectResult?(
      FlutterError(code: "bluetooth_connect_failed", message: message, details: nil)
    )
    pendingConnectResult = nil
  }

  private func succeedConnect() {
    centralManager.stopScan()
    connectTimeoutTimer?.invalidate()
    connectTimeoutTimer = nil
    connectTargetAddress = nil
    pendingConnectResult?(nil)
    pendingConnectResult = nil
  }

  private func disconnectInternal() {
    connectTimeoutTimer?.invalidate()
    connectTimeoutTimer = nil
    connectTargetAddress = nil
    pendingConnectResult = nil
    pendingWriteResult = nil
    pendingWriteData = nil

    if let peripheral = connectedPeripheral {
      centralManager.cancelPeripheralConnection(peripheral)
    }
    connectedPeripheral = nil
    writeCharacteristic = nil
  }

  private func resolveWritableCharacteristic(
    _ peripheral: CBPeripheral
  ) -> CBCharacteristic? {
    for service in peripheral.services ?? [] {
      for characteristic in service.characteristics ?? [] {
        if characteristic.properties.contains(.write)
          || characteristic.properties.contains(.writeWithoutResponse) {
          return characteristic
        }
      }
    }
    return nil
  }

  private func writeNextChunk(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
    guard var data = pendingWriteData, !data.isEmpty else {
      pendingWriteResult?(nil)
      pendingWriteResult = nil
      return
    }

    let chunkSize = max(
      20,
      peripheral.maximumWriteValueLength(
        for: characteristic.properties.contains(.writeWithoutResponse)
          ? .withoutResponse
          : .withResponse
      )
    )
    let chunk = data.prefix(chunkSize)
    data.removeFirst(chunk.count)
    pendingWriteData = data.isEmpty ? nil : data

    let writeType: CBCharacteristicWriteType =
      characteristic.properties.contains(.writeWithoutResponse)
      ? .withoutResponse
      : .withResponse

    peripheral.writeValue(Data(chunk), for: characteristic, type: writeType)

    if writeType == .withoutResponse {
      writeNextChunk(peripheral: peripheral, characteristic: characteristic)
    }
  }
}

// MARK: - CBCentralManagerDelegate

extension BlePrinterManager: CBCentralManagerDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    guard central.state == .poweredOn else { return }
    let callbacks = readyCallbacks
    readyCallbacks.removeAll()
    callbacks.forEach { $0() }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    recordPeripheral(peripheral)

    guard let target = connectTargetAddress else { return }
    if peripheral.identifier.uuidString.uppercased() == target {
      central.stopScan()
      connectToPeripheral(peripheral, timeoutMs: 15000)
    }
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    peripheral.discoverServices(nil)
  }

  func centralManager(
    _ central: CBCentralManager,
    didFailToConnect peripheral: CBPeripheral,
    error: Error?
  ) {
    failConnect(error?.localizedDescription ?? "Could not connect to Bluetooth printer.")
  }

  func centralManager(
    _ central: CBCentralManager,
    didDisconnectPeripheral peripheral: CBPeripheral,
    error: Error?
  ) {
    if peripheral.identifier == connectedPeripheral?.identifier {
      connectedPeripheral = nil
      writeCharacteristic = nil
    }
  }
}

// MARK: - CBPeripheralDelegate

extension BlePrinterManager: CBPeripheralDelegate {
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let error = error {
      failConnect(error.localizedDescription)
      return
    }

    guard let services = peripheral.services, !services.isEmpty else {
      failConnect("No Bluetooth services found on printer.")
      return
    }

    for service in services {
      peripheral.discoverCharacteristics(nil, for: service)
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didDiscoverCharacteristicsFor service: CBService,
    error: Error?
  ) {
    if let error = error {
      failConnect(error.localizedDescription)
      return
    }

    if writeCharacteristic == nil, let found = resolveWritableCharacteristic(peripheral) {
      writeCharacteristic = found
      succeedConnect()
    }
  }

  func peripheral(
    _ peripheral: CBPeripheral,
    didWriteValueFor characteristic: CBCharacteristic,
    error: Error?
  ) {
    if let error = error {
      pendingWriteResult?(
        FlutterError(code: "bluetooth_write_failed", message: error.localizedDescription, details: nil)
      )
      pendingWriteResult = nil
      pendingWriteData = nil
      return
    }

    if let data = pendingWriteData, !data.isEmpty {
      writeNextChunk(peripheral: peripheral, characteristic: characteristic)
      return
    }

    pendingWriteResult?(nil)
    pendingWriteResult = nil
  }
}
