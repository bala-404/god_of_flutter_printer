#include "usb_spool_printer.h"

#include <winspool.h>

#include <sstream>

namespace print_worker_windows {

namespace {

std::string FormatWin32Error(DWORD error_code) {
  LPWSTR buffer = nullptr;
  const DWORD size = FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, error_code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);
  std::string message = "Win32 error " + std::to_string(error_code);
  if (size > 0 && buffer != nullptr) {
    message = WideToUtf8(buffer);
    LocalFree(buffer);
  }
  return message;
}

}  // namespace

std::wstring Utf8ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, wide.data(), length);
  if (!wide.empty() && wide.back() == L'\0') {
    wide.pop_back();
  }
  return wide;
}

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) {
    return std::string();
  }
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (length <= 0) {
    return std::string();
  }
  std::string utf8(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), -1, utf8.data(), length, nullptr, nullptr);
  if (!utf8.empty() && utf8.back() == '\0') {
    utf8.pop_back();
  }
  return utf8;
}

UsbSpoolPrinter::~UsbSpoolPrinter() {
  Disconnect();
}

bool UsbSpoolPrinter::Connect(const std::wstring& printer_name,
                              std::string* error_out) {
  Disconnect();

  if (printer_name.empty()) {
    if (error_out != nullptr) {
      *error_out = "Printer name (deviceId) is empty.";
    }
    return false;
  }

  if (!OpenPrinterW(const_cast<LPWSTR>(printer_name.c_str()), &printer_handle_,
                    nullptr)) {
    if (error_out != nullptr) {
      *error_out = "OpenPrinter failed for '" + WideToUtf8(printer_name) +
                   "': " + FormatWin32Error(GetLastError());
    }
    printer_handle_ = nullptr;
    return false;
  }

  return true;
}

bool UsbSpoolPrinter::WriteRaw(const uint8_t* data, size_t length,
                               std::string* error_out) {
  if (printer_handle_ == nullptr) {
    if (error_out != nullptr) {
      *error_out = "USB printer is not connected.";
    }
    return false;
  }

  if (data == nullptr || length == 0) {
    if (error_out != nullptr) {
      *error_out = "Print payload is empty.";
    }
    return false;
  }

  DOC_INFO_1W doc_info{};
  doc_info.pDocName = const_cast<LPWSTR>(L"Print Worker Job");
  doc_info.pOutputFile = nullptr;
  doc_info.pDatatype = const_cast<LPWSTR>(L"RAW");

  if (!StartDocPrinterW(printer_handle_, 1,
                        reinterpret_cast<LPBYTE>(&doc_info))) {
    if (error_out != nullptr) {
      *error_out =
          "StartDocPrinter failed: " + FormatWin32Error(GetLastError());
    }
    return false;
  }

  if (!StartPagePrinter(printer_handle_)) {
    if (error_out != nullptr) {
      *error_out =
          "StartPagePrinter failed: " + FormatWin32Error(GetLastError());
    }
    EndDocPrinter(printer_handle_);
    return false;
  }

  DWORD bytes_written = 0;
  const BOOL write_ok = WritePrinter(
      printer_handle_, const_cast<uint8_t*>(data), static_cast<DWORD>(length),
      &bytes_written);

  EndPagePrinter(printer_handle_);
  EndDocPrinter(printer_handle_);

  if (!write_ok) {
    if (error_out != nullptr) {
      *error_out = "WritePrinter failed: " + FormatWin32Error(GetLastError());
    }
    return false;
  }

  if (bytes_written != length) {
    if (error_out != nullptr) {
      std::ostringstream stream;
      stream << "Incomplete write: sent " << bytes_written << " of " << length
             << " bytes.";
      *error_out = stream.str();
    }
    return false;
  }

  return true;
}

void UsbSpoolPrinter::Disconnect() {
  if (printer_handle_ != nullptr) {
    ClosePrinter(printer_handle_);
    printer_handle_ = nullptr;
  }
}

bool UsbSpoolPrinter::IsConnected() const {
  return printer_handle_ != nullptr;
}

std::vector<std::wstring> UsbSpoolPrinter::ListPrinters() {
  std::vector<std::wstring> names;
  DWORD needed = 0;
  DWORD count = 0;

  EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2,
                nullptr, 0, &needed, &count);
  if (needed == 0) {
    return names;
  }

  std::vector<BYTE> buffer(needed);
  if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2,
                     buffer.data(), needed, &needed, &count)) {
    return names;
  }

  auto* printers = reinterpret_cast<PRINTER_INFO_2W*>(buffer.data());
  names.reserve(count);
  for (DWORD i = 0; i < count; ++i) {
    if (printers[i].pPrinterName != nullptr) {
      names.emplace_back(printers[i].pPrinterName);
    }
  }
  return names;
}

}  // namespace print_worker_windows
