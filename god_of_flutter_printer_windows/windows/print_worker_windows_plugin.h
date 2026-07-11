#ifndef FLUTTER_PLUGIN_PRINT_WORKER_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_PRINT_WORKER_WINDOWS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

#include "usb_spool_printer.h"
#include "bluetooth_spp_printer.h"

namespace print_worker_windows {

class PrintWorkerWindowsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  PrintWorkerWindowsPlugin();

  virtual ~PrintWorkerWindowsPlugin();

  PrintWorkerWindowsPlugin(const PrintWorkerWindowsPlugin&) = delete;
  PrintWorkerWindowsPlugin& operator=(const PrintWorkerWindowsPlugin&) = delete;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  UsbSpoolPrinter usb_printer_;
  BluetoothSppPrinter bluetooth_printer_;
};

}  // namespace print_worker_windows

#endif  // FLUTTER_PLUGIN_PRINT_WORKER_WINDOWS_PLUGIN_H_
