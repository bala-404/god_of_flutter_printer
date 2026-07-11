#include "print_worker_windows_plugin.h"

#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace print_worker_windows {

namespace {

const char kChannelName[] = "com.godofflutterprinter/platform";

std::string GetStringArg(const flutter::EncodableMap& args,
                         const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return std::string();
  }
  if (const auto* value = std::get_if<std::string>(&it->second)) {
    return *value;
  }
  return std::string();
}

const std::vector<uint8_t>* GetBytesArg(const flutter::EncodableMap& args,
                                        const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) {
    return nullptr;
  }
  return std::get_if<std::vector<uint8_t>>(&it->second);
}

}  // namespace

void PrintWorkerWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<PrintWorkerWindowsPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

PrintWorkerWindowsPlugin::PrintWorkerWindowsPlugin() {}

PrintWorkerWindowsPlugin::~PrintWorkerWindowsPlugin() {}

void PrintWorkerWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();

  if (method == "listUsbPrinters") {
    flutter::EncodableList printers;
    for (const auto& name : UsbSpoolPrinter::ListPrinters()) {
      printers.push_back(flutter::EncodableValue(WideToUtf8(name)));
    }
    result->Success(flutter::EncodableValue(printers));
    return;
  }

  if (method == "listBluetoothDevices") {
    flutter::EncodableList devices;
    for (const auto& device : BluetoothSppPrinter::ListPairedDevices()) {
      flutter::EncodableMap map;
      map[flutter::EncodableValue("name")] = flutter::EncodableValue(device.name);
      map[flutter::EncodableValue("address")] =
          flutter::EncodableValue(device.address);
      map[flutter::EncodableValue("type")] = flutter::EncodableValue("classic");
      devices.push_back(flutter::EncodableValue(map));
    }
    result->Success(flutter::EncodableValue(devices));
    return;
  }

  if (method == "usbConnect") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args == nullptr) {
      result->Error("invalid_args", "usbConnect requires a map argument.");
      return;
    }

    const std::string device_id = GetStringArg(*args, "deviceId");
    std::string error;
    if (!usb_printer_.Connect(Utf8ToWide(device_id), &error)) {
      result->Error("usb_connect_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (method == "usbWrite") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args == nullptr) {
      result->Error("invalid_args", "usbWrite requires a map argument.");
      return;
    }

    const auto* data = GetBytesArg(*args, "data");
    if (data == nullptr || data->empty()) {
      result->Error("invalid_args", "usbWrite requires non-empty data bytes.");
      return;
    }

    std::string error;
    if (!usb_printer_.WriteRaw(data->data(), data->size(), &error)) {
      result->Error("usb_write_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (method == "usbDisconnect") {
    usb_printer_.Disconnect();
    result->Success();
    return;
  }

  if (method == "bluetoothConnect") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args == nullptr) {
      result->Error("invalid_args", "bluetoothConnect requires a map argument.");
      return;
    }

    const std::string address = GetStringArg(*args, "address");
    std::string error;
    if (!bluetooth_printer_.Connect(address, &error)) {
      result->Error("bluetooth_connect_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (method == "bluetoothWrite") {
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args == nullptr) {
      result->Error("invalid_args", "bluetoothWrite requires a map argument.");
      return;
    }

    const auto* data = GetBytesArg(*args, "data");
    if (data == nullptr || data->empty()) {
      result->Error("invalid_args", "bluetoothWrite requires non-empty data.");
      return;
    }

    std::string error;
    if (!bluetooth_printer_.WriteRaw(data->data(), data->size(), &error)) {
      result->Error("bluetooth_write_failed", error);
      return;
    }
    result->Success();
    return;
  }

  if (method == "bluetoothDisconnect") {
    bluetooth_printer_.Disconnect();
    result->Success();
    return;
  }

  if (method == "bleConnect" || method == "bleWrite" || method == "bleDisconnect") {
    result->Error("not_implemented",
                  "BLE printing is not implemented on Windows yet. Use Bluetooth Classic.");
    return;
  }

  result->NotImplemented();
}

}  // namespace print_worker_windows
