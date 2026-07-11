#ifndef PRINT_WORKER_BLUETOOTH_SPP_PRINTER_H_
#define PRINT_WORKER_BLUETOOTH_SPP_PRINTER_H_

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

namespace print_worker_windows {

struct BluetoothDeviceEntry {
  std::string name;
  std::string address;
};

/// Bluetooth Classic SPP (RFCOMM) transport for ESC/POS bytes.
class BluetoothSppPrinter {
 public:
  BluetoothSppPrinter();
  ~BluetoothSppPrinter();

  BluetoothSppPrinter(const BluetoothSppPrinter&) = delete;
  BluetoothSppPrinter& operator=(const BluetoothSppPrinter&) = delete;

  bool Connect(const std::string& address, std::string* error_out);
  bool WriteRaw(const uint8_t* data, size_t length, std::string* error_out);
  void Disconnect();
  bool IsConnected() const;

  static std::vector<BluetoothDeviceEntry> ListPairedDevices();

 private:
  // Stored as uintptr_t to keep Winsock headers out of public includes.
  uintptr_t socket_ = static_cast<uintptr_t>(-1);
  bool wsa_started_ = false;
};

}  // namespace print_worker_windows

#endif  // PRINT_WORKER_BLUETOOTH_SPP_PRINTER_H_
