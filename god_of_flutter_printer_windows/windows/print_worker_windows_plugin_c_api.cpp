#include "include/print_worker_windows/print_worker_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "print_worker_windows_plugin.h"

void PrintWorkerWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  print_worker_windows::PrintWorkerWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
