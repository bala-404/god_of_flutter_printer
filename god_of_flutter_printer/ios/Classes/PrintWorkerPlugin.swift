import Flutter
import UIKit

public class PrintWorkerPlugin: NSObject, FlutterPlugin {
  private let bleManager = BlePrinterManager()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.godofflutterprinter/platform",
      binaryMessenger: registrar.messenger())
    let instance = PrintWorkerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "listUsbPrinters":
      result([])

    case "listBluetoothDevices":
      bleManager.listBluetoothDevices(result: result)

    case "bluetoothConnect", "bleConnect":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_args", message: "Arguments map is required", details: nil))
        return
      }
      let address = (args["address"] as? String) ?? (args["deviceId"] as? String) ?? ""
      let timeoutMs = args["timeoutMs"] as? Int ?? 15000
      bleManager.connect(address: address, timeoutMs: timeoutMs, result: result)

    case "bluetoothWrite", "bleWrite":
      guard let args = call.arguments as? [String: Any],
            let data = args["data"] as? FlutterStandardTypedData,
            !data.data.isEmpty else {
        result(FlutterError(code: "invalid_args", message: "data bytes are required", details: nil))
        return
      }
      bleManager.write(data: data.data, result: result)

    case "bluetoothDisconnect", "bleDisconnect":
      bleManager.disconnect()
      result(nil)

    case "usbConnect", "usbWrite", "usbDisconnect":
      result(FlutterError(
        code: "not_supported",
        message: "USB printing is not supported on iOS. Use Bluetooth or network.",
        details: nil))

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
