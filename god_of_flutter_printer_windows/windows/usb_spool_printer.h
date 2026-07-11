#ifndef PRINT_WORKER_USB_SPOOL_PRINTER_H_
#define PRINT_WORKER_USB_SPOOL_PRINTER_H_

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace print_worker_windows {

std::wstring Utf8ToWide(const std::string& utf8);
std::string WideToUtf8(const std::wstring& wide);

/// Sends raw ESC/POS (or TSPL/ZPL) bytes through the Windows print spooler.
class UsbSpoolPrinter {
 public:
  UsbSpoolPrinter() = default;
  ~UsbSpoolPrinter();

  UsbSpoolPrinter(const UsbSpoolPrinter&) = delete;
  UsbSpoolPrinter& operator=(const UsbSpoolPrinter&) = delete;

  bool Connect(const std::wstring& printer_name, std::string* error_out);
  bool WriteRaw(const uint8_t* data, size_t length, std::string* error_out);
  void Disconnect();
  bool IsConnected() const;

  static std::vector<std::wstring> ListPrinters();

 private:
  HANDLE printer_handle_ = nullptr;
};

}  // namespace print_worker_windows

#endif  // PRINT_WORKER_USB_SPOOL_PRINTER_H_
