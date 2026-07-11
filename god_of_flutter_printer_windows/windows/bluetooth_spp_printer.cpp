#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif

#include <winsock2.h>
#include <ws2bth.h>
#include <windows.h>
#include <BluetoothAPIs.h>

#include <iomanip>
#include <sstream>
#include <cstdio>
#include <cstdlib>

#include "bluetooth_spp_printer.h"
#include "usb_spool_printer.h"

#pragma comment(lib, "Bthprops.lib")
#pragma comment(lib, "ws2_32.lib")

namespace print_worker_windows {

namespace {

constexpr uintptr_t kInvalidSocket = static_cast<uintptr_t>(INVALID_SOCKET);

bool ParseBluetoothAddress(const std::string& address, ULONGLONG* out_addr,
                           std::string* error_out) {
  if (out_addr == nullptr) {
    return false;
  }

  unsigned int bytes[6] = {};
  int matched = sscanf_s(
      address.c_str(), "%02x:%02x:%02x:%02x:%02x:%02x", &bytes[0], &bytes[1],
      &bytes[2], &bytes[3], &bytes[4], &bytes[5]);
  if (matched != 6) {
    std::string digits;
    digits.reserve(12);
    for (char ch : address) {
      if ((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') ||
          (ch >= 'A' && ch <= 'F')) {
        digits.push_back(ch);
      }
    }
    if (digits.size() != 12) {
      if (error_out != nullptr) {
        *error_out = "Invalid Bluetooth address. Use format AA:BB:CC:DD:EE:FF";
      }
      return false;
    }
    for (int i = 0; i < 6; ++i) {
      const std::string pair = digits.substr(static_cast<size_t>(i * 2), 2);
      bytes[i] = static_cast<unsigned int>(strtoul(pair.c_str(), nullptr, 16));
    }
  }

  ULONGLONG bt_addr = 0;
  for (int i = 0; i < 6; ++i) {
    bt_addr |= static_cast<ULONGLONG>(bytes[i]) << (8 * i);
  }
  *out_addr = bt_addr;
  return true;
}

std::string FormatBluetoothAddress(ULONGLONG bt_addr) {
  std::ostringstream stream;
  stream << std::hex << std::setfill('0');
  for (int i = 0; i < 6; ++i) {
    if (i > 0) {
      stream << ':';
    }
    const auto byte_value =
        static_cast<unsigned int>((bt_addr >> (8 * i)) & 0xFF);
    stream << std::setw(2) << byte_value;
  }
  return stream.str();
}

SOCKET AsSocket(uintptr_t handle) {
  return static_cast<SOCKET>(handle);
}

}  // namespace

BluetoothSppPrinter::BluetoothSppPrinter() {
  WSADATA wsa_data{};
  if (WSAStartup(MAKEWORD(2, 2), &wsa_data) == 0) {
    wsa_started_ = true;
  }
}

BluetoothSppPrinter::~BluetoothSppPrinter() {
  Disconnect();
  if (wsa_started_) {
    WSACleanup();
  }
}

bool BluetoothSppPrinter::Connect(const std::string& address,
                                  std::string* error_out) {
  Disconnect();

  ULONGLONG bt_addr = 0;
  std::string parse_error;
  if (!ParseBluetoothAddress(address, &bt_addr, &parse_error)) {
    if (error_out != nullptr) {
      *error_out = parse_error;
    }
    return false;
  }

  DWORD last_error = 0;
  for (UCHAR port = 1; port <= 5; ++port) {
    SOCKET socket = ::socket(AF_BTH, SOCK_STREAM, BTHPROTO_RFCOMM);
    if (socket == INVALID_SOCKET) {
      if (error_out != nullptr) {
        *error_out = "Failed to create Bluetooth socket.";
      }
      return false;
    }

    SOCKADDR_BTH sock_addr{};
    sock_addr.addressFamily = AF_BTH;
    sock_addr.btAddr = bt_addr;
    sock_addr.serviceClassId = RFCOMM_PROTOCOL_UUID;
    sock_addr.port = port;

    if (::connect(socket, reinterpret_cast<SOCKADDR*>(&sock_addr),
                  sizeof(sock_addr)) != SOCKET_ERROR) {
      socket_ = static_cast<uintptr_t>(socket);
      return true;
    }

    last_error = WSAGetLastError();
    closesocket(socket);
  }

  if (error_out != nullptr) {
    std::ostringstream stream;
    stream << "Bluetooth connect failed (WSA " << last_error
           << "). Pair the printer in Windows Settings first.";
    *error_out = stream.str();
  }
  return false;
}

bool BluetoothSppPrinter::WriteRaw(const uint8_t* data, size_t length,
                                   std::string* error_out) {
  if (socket_ == kInvalidSocket) {
    if (error_out != nullptr) {
      *error_out = "Bluetooth socket is not connected.";
    }
    return false;
  }

  const SOCKET socket = AsSocket(socket_);
  size_t offset = 0;
  while (offset < length) {
    const int chunk = ::send(
        socket, reinterpret_cast<const char*>(data + offset),
        static_cast<int>(length - offset), 0);
    if (chunk == SOCKET_ERROR || chunk == 0) {
      if (error_out != nullptr) {
        std::ostringstream stream;
        stream << "Bluetooth write failed (WSA " << WSAGetLastError() << ")";
        *error_out = stream.str();
      }
      return false;
    }
    offset += static_cast<size_t>(chunk);
  }

  return true;
}

void BluetoothSppPrinter::Disconnect() {
  if (socket_ != kInvalidSocket) {
    closesocket(AsSocket(socket_));
    socket_ = kInvalidSocket;
  }
}

bool BluetoothSppPrinter::IsConnected() const {
  return socket_ != kInvalidSocket;
}

std::vector<BluetoothDeviceEntry> BluetoothSppPrinter::ListPairedDevices() {
  std::vector<BluetoothDeviceEntry> devices;

  BLUETOOTH_DEVICE_SEARCH_PARAMS search_params{};
  search_params.dwSize = sizeof(search_params);
  search_params.fReturnAuthenticated = TRUE;
  search_params.fReturnRemembered = TRUE;
  search_params.fReturnConnected = TRUE;
  search_params.fReturnUnknown = FALSE;
  search_params.fIssueInquiry = FALSE;
  search_params.cTimeoutMultiplier = 1;

  BLUETOOTH_DEVICE_INFO device_info{};
  device_info.dwSize = sizeof(device_info);

  HBLUETOOTH_DEVICE_FIND find_handle =
      BluetoothFindFirstDevice(&search_params, &device_info);
  if (find_handle == nullptr) {
    return devices;
  }

  do {
    BluetoothDeviceEntry entry;
    entry.name = WideToUtf8(device_info.szName);
    if (entry.name.empty()) {
      entry.name = "Bluetooth device";
    }

    entry.address =
        FormatBluetoothAddress(device_info.Address.ullLong);
    devices.push_back(entry);
  } while (BluetoothFindNextDevice(find_handle, &device_info));

  BluetoothFindDeviceClose(find_handle);
  return devices;
}

}  // namespace print_worker_windows
