import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

import 'connection_flow_help.dart';
import 'platform_connection_config.dart';
import 'payload_preview.dart';
import 'payload_preview_panel.dart';
import 'widgets/paste_text_field.dart';
import 'developer/developer_hub_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  runApp(const PrintWorkerExampleApp());
}

class PrintWorkerExampleApp extends StatelessWidget {
  const PrintWorkerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      visualDensity: VisualDensity.standard,
    );

    return MaterialApp(
      title: 'Print Worker Demo',
      theme: baseTheme.copyWith(
        textTheme: GoogleFonts.notoSansTextTheme(baseTheme.textTheme).apply(
          bodyColor: const Color(0xFF1A1A1A),
          displayColor: const Color(0xFF1A1A1A),
        ),
      ),
      home: const PrintDemoPage(),
    );
  }
}

class PrintDemoPage extends StatefulWidget {
  const PrintDemoPage({super.key});

  @override
  State<PrintDemoPage> createState() => _PrintDemoPageState();
}

class _PrintDemoPageState extends State<PrintDemoPage> {
  final _worker = PrintWorker.instance;
  final _payloadEncoder = PayloadEncoder(
    templateEngine: TemplateEngine(TemplateRepository()),
  );

  final _hostController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '9100');
  final _agentUrlController = TextEditingController();
  int _paperWidthMm = 80;
  final _customTextController = TextEditingController(
    text: 'வணக்கம்\nEnter any text here',
  );

  DemoPlatform _demoPlatform = PlatformConnectionRules.detectRuntimePlatform();
  ConnectionType _connectionType =
      PlatformConnectionRules.defaultConnection(
        PlatformConnectionRules.detectRuntimePlatform(),
      );
  PrintMode _mode = PrintMode.text;
  String _selectedTemplate = 'tamil_check_80';
  String? _lastJobId;
  JobResult? _lastResult;
  final List<JobLogEntry> _logs = [];
  List<String> _usbPrinters = [];
  String? _selectedUsbPrinter;
  bool _loadingPrinters = false;
  AgentProbeResult? _agentProbe;
  final _manualPrinterController = TextEditingController();
  bool _useManualPrinter = false;
  List<BluetoothDeviceInfo> _bluetoothDevices = [];
  String? _selectedBluetoothAddress;
  String? _bluetoothStatus;

  Timer? _previewDebounce;
  bool _previewLoading = false;
  bool _previewExpanded = !kIsWeb;
  PreviewTab _previewTab = PreviewTab.dart;
  String _previewDart = '';
  String _previewJson = '';
  String _previewHex = '';

  @override
  void initState() {
    super.initState();
    _agentUrlController.text = _defaultAgentUrl();

    final runtime = _runtimePlatform;
    final allowed = PlatformConnectionRules.allowedConnections(runtime);
    if (!allowed.contains(_connectionType)) {
      _connectionType = PlatformConnectionRules.defaultConnection(runtime);
    }
    _demoPlatform = runtime;

    _worker.logStream.listen((entry) {
      if (!mounted) return;
      setState(() {
        _logs.insert(0, entry);
        if (_logs.length > 100) _logs.removeLast();
      });
    });
    _worker.jobEvents.listen((event) {
      if (event.jobId == _lastJobId && mounted) {
        setState(() {
          _lastResult = _worker.getJobStatus(event.jobId);
        });
      }
    });

    for (final controller in [
      _hostController,
      _portController,
      _agentUrlController,
      _customTextController,
    ]) {
      controller.addListener(_schedulePreviewRefresh);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPrinters();
      if (!kIsWeb) _refreshPreview();
    });
  }

  void _schedulePreviewRefresh() {
    if (!_previewExpanded) return;
    _previewDebounce?.cancel();
    _previewDebounce = Timer(
      Duration(milliseconds: kIsWeb ? 800 : 400),
      _refreshPreview,
    );
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _hostController.dispose();
    _portController.dispose();
    _agentUrlController.dispose();
    _manualPrinterController.dispose();
    _customTextController.dispose();
    super.dispose();
  }

  String _defaultAgentUrl() {
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      if (pageHost.isNotEmpty && pageHost != '0.0.0.0') {
        return 'http://$pageHost:9280';
      }
      return 'http://localhost:9280';
    }
    return 'http://127.0.0.1:9280';
  }

  DemoPlatform get _runtimePlatform =>
      PlatformConnectionRules.detectRuntimePlatform();

  bool get _usesPrintHub => ConnectionFlowHelp.needsPrintHub(
        runtime: _runtimePlatform,
        connection: _connectionType,
      );

  Future<AgentProbeResult?> _probeHub() async {
    if (!_usesPrintHub) return null;

    final probe = await _worker.probePrintAgent(
      _agentUrlController.text.trim(),
      discover: kIsWeb,
    );
    _applyResolvedAgentUrl(probe.baseUrl);
    if (mounted) {
      setState(() => _agentProbe = probe);
    }
    return probe;
  }

  void _applyResolvedAgentUrl(String? url) {
    if (url == null || url.isEmpty) return;
    if (_agentUrlController.text.trim() != url) {
      _agentUrlController.text = url;
    }
  }

  Future<void> _loadPrinters() async {
    if (!mounted) return;
    setState(() {
      _loadingPrinters = true;
      _agentProbe = null;
    });

    try {
      switch (_connectionType) {
        case ConnectionType.webAgent:
          final probe = await _probeHub();
          if (!mounted || probe == null) return;
          setState(() {
            _usbPrinters = probe.printers;
            _selectedUsbPrinter =
                probe.printers.isNotEmpty ? probe.printers.first : null;
            _loadingPrinters = false;
            if (probe.hasPrinters) _useManualPrinter = false;
          });
        case ConnectionType.usb:
          final printers = await _worker.listUsbPrinters();
          if (!mounted) return;
          setState(() {
            _usbPrinters = printers;
            _selectedUsbPrinter = printers.isNotEmpty ? printers.first : null;
            _loadingPrinters = false;
          });
        case ConnectionType.bluetooth:
          if (kIsWeb) {
            final probe = await _probeHub();
            if (!mounted || probe == null) return;
            if (!probe.online) {
              setState(() {
                _bluetoothDevices = [];
                _selectedBluetoothAddress = null;
                _bluetoothStatus = probe.error ??
                    'Cannot reach print agent. Run print_agent on this PC, '
                    'paste the LAN URL from the hub app, then tap Refresh.';
                _loadingPrinters = false;
              });
              return;
            }

            final devices = await _worker.listBluetoothDevices(
              agentBaseUrl: probe.baseUrl ?? _agentUrlController.text.trim(),
            );
            if (!mounted) return;
            setState(() {
              _bluetoothDevices = devices;
              _selectedBluetoothAddress =
                  devices.isNotEmpty ? devices.first.address : null;
              _bluetoothStatus = devices.isEmpty
                  ? 'No paired Bluetooth devices found. Pair the printer in '
                      'Windows Settings, then tap Refresh.'
                  : '${devices.length} paired device(s) found';
              _loadingPrinters = false;
            });
          } else {
            final devices = await _worker.listBluetoothDevices();
            if (!mounted) return;
            setState(() {
              _bluetoothDevices = devices;
              _selectedBluetoothAddress =
                  devices.isNotEmpty ? devices.first.address : null;
              _bluetoothStatus = devices.isEmpty
                  ? 'No paired Bluetooth devices. Pair the printer in system settings, then refresh.'
                  : '${devices.length} paired device(s) found';
              _loadingPrinters = false;
            });
          }
        case ConnectionType.network:
          if (kIsWeb) {
            final probe = await _probeHub();
            if (!mounted) return;
            setState(() {
              _loadingPrinters = false;
              if (probe != null && !probe.online) {
                _bluetoothStatus = probe.error;
              }
            });
          } else if (!mounted) {
            return;
          } else {
            setState(() => _loadingPrinters = false);
          }
      }
      if (_previewExpanded) _refreshPreview();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _usbPrinters = [];
        _selectedUsbPrinter = null;
        _agentProbe = AgentProbeResult(online: false, error: error.toString());
        _loadingPrinters = false;
      });
    }
  }

  String? get _effectivePrinterName {
    if (_useManualPrinter) {
      final manual = _manualPrinterController.text.trim();
      return manual.isEmpty ? null : manual;
    }
    return _selectedUsbPrinter;
  }

  PrintConnection _buildConnection() {
    if (!kIsWeb && _connectionType == ConnectionType.webAgent) {
      throw StateError(
        'Print Hub is web-only. On Windows use USB or Bluetooth connection type.',
      );
    }

    switch (_connectionType) {
      case ConnectionType.webAgent:
        return PrintConnection.localAgent(
          baseUrl: _agentUrlController.text.trim(),
          printerName: _effectivePrinterName ?? '',
        );
      case ConnectionType.usb:
        return PrintConnection.usb(deviceId: _selectedUsbPrinter ?? '');
      case ConnectionType.bluetooth:
        if (kIsWeb) {
          return PrintConnection.bluetoothAgent(
            baseUrl: _agentUrlController.text.trim(),
            address: _selectedBluetoothAddress ?? '',
          );
        }
        return PrintConnection.bluetooth(
          address: _selectedBluetoothAddress ?? '',
        );
      case ConnectionType.network:
        final host = _hostController.text.trim();
        final port = int.tryParse(_portController.text.trim()) ?? 9100;
        if (kIsWeb) {
          return PrintConnection.networkAgent(
            baseUrl: _agentUrlController.text.trim(),
            host: host,
            port: port,
          );
        }
        return PrintConnection.network(host: host, port: port);
    }
  }

  void _onDemoPlatformChanged(DemoPlatform platform) {
    final allowed = PlatformConnectionRules.allowedConnections(platform);
    setState(() {
      _demoPlatform = platform;
      if (!allowed.contains(_connectionType)) {
        _connectionType = PlatformConnectionRules.defaultConnection(platform);
      }
    });
    _loadPrinters();
  }

  void _onConnectionTypeChanged(ConnectionType type) {
    setState(() => _connectionType = type);
    _loadPrinters();
  }

  String? _detectLocale(String text) {
    if (!ScriptUtils.needsMultilingualEncoding(text)) return null;
    final locale = ScriptUtils.detectLocale(text);
    return switch (locale) {
      ScriptLocale.tamil => 'ta',
      ScriptLocale.hindi => 'hi',
      _ => 'ta',
    };
  }

  Future<PrintPayload> _buildPayload(int paper) async {
    final customText = _customTextController.text;
    switch (_mode) {
      case PrintMode.text:
        return PrintPayload.text(
          customText,
          charset: _detectLocale(customText),
        );
      case PrintMode.template:
        return PrintPayload.template(
          templateId: _selectedTemplate,
          data: _sampleTemplateData(),
        );
      case PrintMode.document:
        return PrintPayload.document(_sampleDocumentJson());
      case PrintMode.raw:
        return PrintPayload.raw(
          await EscPosEncoder(
            paperWidthMm: paper,
            allowRasterFallback: true,
          ).encodeText(
            customText,
            locale: _detectLocale(customText),
          ),
        );
    }
  }

  PrintRequest _buildRequest(PrintPayload payload, int paper) {
    return PrintRequest(
      connection: _buildConnection(),
      protocol: PrintProtocol.escPos,
      paperWidthMm: paper,
      mode: _mode,
      payload: payload,
      options: const PrintOptions(allowRasterFallback: true),
    );
  }

  Future<void> _refreshPreview() async {
    if (!mounted || !_previewExpanded) return;
    setState(() => _previewLoading = true);

    try {
      final paper = _paperWidthMm;
      final payload = await _buildPayload(paper);
      final request = _buildRequest(payload, paper);
      final bytes = await _payloadEncoder.encode(request);

      if (!mounted) return;
      setState(() {
        _previewDart = PayloadPreview.dartCode(request);
        _previewJson = PayloadPreview.jsonRequest(request);
        _previewHex = PayloadPreview.hexDump(
          bytes,
          maxBytes: kIsWeb ? 256 : 384,
        );
        _previewLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _previewDart = '// Preview error: $error';
        _previewJson = '{"error": "$error"}';
        _previewHex = '(encoding failed)';
        _previewLoading = false;
      });
    }
  }

  void _togglePreviewExpanded() {
    setState(() => _previewExpanded = !_previewExpanded);
    if (_previewExpanded && _previewDart.isEmpty) {
      _refreshPreview();
    }
  }

  Future<void> _print() async {
    final paper = _paperWidthMm;

    if ((_connectionType == ConnectionType.usb ||
            _connectionType == ConnectionType.webAgent) &&
        (_effectivePrinterName == null || _effectivePrinterName!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _connectionType == ConnectionType.webAgent
                ? 'Start print_agent, refresh printers, or enter the Windows printer name manually'
                : 'Select a USB printer first',
          ),
        ),
      );
      return;
    }

    if (_connectionType == ConnectionType.bluetooth &&
        (_selectedBluetoothAddress == null ||
            _selectedBluetoothAddress!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kIsWeb
                ? 'Start print_agent on this PC, tap Refresh, then select a Bluetooth printer'
                : 'Select a paired Bluetooth printer first',
          ),
        ),
      );
      return;
    }

    if (_connectionType == ConnectionType.network &&
        _hostController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter printer IP address')),
      );
      return;
    }

    if (_usesPrintHub && (_agentProbe == null || !_agentProbe!.online)) {
      final probe = await _probeHub();
      if (probe == null || !probe.online) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              probe?.error ??
                  'Cannot reach print hub. Start print_agent and paste the hub URL.',
            ),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    final customText = _customTextController.text;
    if (_mode == PrintMode.text && customText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter text to print')),
      );
      return;
    }

    final payload = await _buildPayload(paper);
    final request = _buildRequest(payload, paper);

    if (_previewExpanded) await _refreshPreview();

    final jobId = await _worker.execute(request);

    if (!mounted) return;

    JobResult? result;
    try {
      result = await _worker.waitForJob(
        jobId,
        timeout: const Duration(seconds: 90),
      );
    } catch (error) {
      result = _worker.getJobStatus(jobId);
    }

    if (!mounted) return;
    setState(() {
      _lastJobId = jobId;
      _lastResult = result ?? _worker.getJobStatus(jobId);
    });

    final finalResult = _lastResult;
    if (finalResult?.isFailed == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Print failed: ${finalResult!.errorMessage}'),
          duration: const Duration(seconds: 8),
        ),
      );
    } else if (finalResult?.isCompleted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Printed (${finalResult!.bytesSent} bytes)')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Job submitted: $jobId')),
      );
    }
  }

  Future<void> _copyPreview(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  Map<String, dynamic> _sampleTemplateData() {
    if (_selectedTemplate == 'tamil_check_80') {
      return {
        'locale': 'ta',
        'greeting': 'வணக்கம்',
        'shopName': 'அகம கடை',
        'orderId': 'TA-1001',
        'date': DateTime.now().toString().substring(0, 10),
        'total': '200.00',
        'thankYou': 'வணக்கம்',
        'englishNote': 'Tamil print test',
        'items': [
          {'nameTa': 'வக 1', 'qty': '2', 'amount': '120.00'},
          {'nameTa': 'மக 2', 'qty': '1', 'amount': '80.00'},
        ],
      };
    }

    if (_selectedTemplate == 'kitchen_kot_80') {
      return {
        'dateTime': '06/07/26 14:18',
        'orderNo': '234',
        'orderType': 'Pick Up',
        'biller': 'biller2',
        'items': [
          {
            'name': 'Veg Biryani',
            'specialNote': 'Less spicy',
            'qty': '1',
          },
          {
            'name': 'Paneer Butter Masala',
            'specialNote': '--',
            'qty': '2',
          },
        ],
      };
    }

    return {
      'shopName': 'Demo Shop',
      'shopAddress': '123 Main Street',
      'billNo': 'INV-1024',
      'date': DateTime.now().toString().substring(0, 10),
      'total': '500.00',
      'items': [
        {'name': 'Item A', 'qty': '2', 'amount': '300.00'},
        {'name': 'Item B', 'qty': '1', 'amount': '200.00'},
      ],
    };
  }

  Map<String, dynamic> _sampleDocumentJson() {
    return {
      'blocks': [
        {
          'type': 'text',
          'text': _customTextController.text,
          'locale': _detectLocale(_customTextController.text),
        },
        {'type': 'feed', 'lines': 2},
        {'type': 'cut'},
      ],
    };
  }

  List<DropdownMenuItem<ConnectionType>> _connectionItems() {
    return PlatformConnectionRules.allowedConnections(_runtimePlatform)
        .map(
          (type) => DropdownMenuItem(
            value: type,
            child: Text(type.label),
          ),
        )
        .toList();
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Worker Demo'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeveloperHubPage(),
                ),
              );
            },
            icon: const Icon(Icons.developer_mode),
            tooltip: 'Developer — build Print Hub EXE',
          ),
          IconButton(
            onPressed: _loadingPrinters ? null : _loadPrinters,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh devices',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Print content', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _customTextController,
                          style: GoogleFonts.notoSansTamil(
                            textStyle: textTheme.bodyLarge,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Text to print',
                            hintText: 'English, Tamil, Hindi...',
                            alignLabelWithHint: true,
                          ),
                          minLines: 3,
                          maxLines: 8,
                          keyboardType: TextInputType.multiline,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Platform & connection', style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: Icon(
                                kIsWeb ? Icons.language : Icons.desktop_windows,
                                size: 18,
                              ),
                              label: Text('Running: ${ConnectionFlowHelp.runtimeLabel()}'),
                            ),
                            if (_agentProbe?.online == true)
                              Chip(
                                avatar: const Icon(Icons.link, size: 18, color: Colors.green),
                                label: const Text('Hub connected'),
                              )
                            else if (_usesPrintHub && _agentProbe != null)
                              Chip(
                                avatar: Icon(
                                  Icons.link_off,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                label: const Text('Hub offline'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<DemoPlatform>(
                          value: _demoPlatform,
                          decoration: const InputDecoration(
                            labelText: 'Docs: simulate platform',
                          ),
                          items: DemoPlatform.values
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(p.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) _onDemoPlatformChanged(value);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PlatformConnectionRules.platformHint(_demoPlatform),
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ConnectionType>(
                          value: _connectionType,
                          decoration: const InputDecoration(
                            labelText: 'Connection type',
                          ),
                          items: _connectionItems(),
                          onChanged: (value) {
                            if (value != null) _onConnectionTypeChanged(value);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ConnectionFlowHelp.connectionHint(
                            runtime: _runtimePlatform,
                            connection: _connectionType,
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (_usesPrintHub) ...[
                          const SizedBox(height: 12),
                          PasteTextField(
                            controller: _agentUrlController,
                            labelText: 'Print hub URL (paste from hub app)',
                            hintText: 'http://192.168.1.50:9280',
                            onSubmitted: (_) => _loadPrinters(),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: _loadingPrinters ? null : _loadPrinters,
                            icon: const Icon(Icons.wifi_find, size: 18),
                            label: const Text('Test hub & refresh'),
                          ),
                          if (_agentProbe != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _agentProbe!.online
                                  ? 'Hub online${_agentProbe!.baseUrl != null ? ' · ${_agentProbe!.baseUrl}' : ''}'
                                  : (_agentProbe!.error ?? 'Hub offline'),
                              style: textTheme.bodySmall?.copyWith(
                                color: _agentProbe!.online
                                    ? Colors.green.shade800
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        if (_connectionType == ConnectionType.network) ...[
                          PasteTextField(
                            controller: _hostController,
                            labelText: 'Printer IP',
                            hintText: '192.168.1.100',
                          ),
                          const SizedBox(height: 12),
                          PasteTextField(
                            controller: _portController,
                            labelText: 'Port',
                            keyboardType: TextInputType.number,
                          ),
                        ] else if (_connectionType == ConnectionType.webAgent) ...[
                          if (_loadingPrinters)
                            const LinearProgressIndicator()
                          else if (_usbPrinters.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: _selectedUsbPrinter,
                              decoration: const InputDecoration(
                                labelText: 'Printer (from agent)',
                              ),
                              items: _usbPrinters
                                  .map(
                                    (name) => DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _useManualPrinter
                                  ? null
                                  : (value) {
                                      setState(() => _selectedUsbPrinter = value);
                                      _schedulePreviewRefresh();
                                    },
                            ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Enter printer name manually'),
                            value: _useManualPrinter,
                            onChanged: (value) {
                              setState(() => _useManualPrinter = value);
                              _schedulePreviewRefresh();
                            },
                          ),
                          if (_useManualPrinter)
                            PasteTextField(
                              controller: _manualPrinterController,
                              labelText: 'Windows printer name',
                              onChanged: (_) => _schedulePreviewRefresh(),
                            ),
                        ] else if (_connectionType == ConnectionType.bluetooth) ...[
                          if (_loadingPrinters)
                            const LinearProgressIndicator()
                          else if (_bluetoothDevices.isEmpty)
                            Text(
                              _bluetoothStatus ??
                                  'No paired Bluetooth devices found.',
                              style: textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedBluetoothAddress,
                              decoration: const InputDecoration(
                                labelText: 'Paired Bluetooth printer',
                              ),
                              items: _bluetoothDevices
                                  .map(
                                    (device) => DropdownMenuItem(
                                      value: device.address,
                                      child: Text('${device.name} (${device.address})'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedBluetoothAddress = value);
                                _schedulePreviewRefresh();
                              },
                            ),
                          if (_bluetoothStatus != null &&
                              _bluetoothDevices.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_bluetoothStatus!, style: textTheme.bodySmall),
                          ],
                        ] else ...[
                          if (_loadingPrinters)
                            const LinearProgressIndicator()
                          else if (_usbPrinters.isEmpty)
                            Text(
                              'No USB printers found. Install driver and refresh.',
                              style: textTheme.bodySmall,
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedUsbPrinter,
                              decoration: const InputDecoration(
                                labelText: 'Windows printer name',
                              ),
                              items: _usbPrinters
                                  .map(
                                    (name) => DropdownMenuItem(
                                      value: name,
                                      child: Text(name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _selectedUsbPrinter = value);
                                _schedulePreviewRefresh();
                              },
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Job options', style: textTheme.titleMedium),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: _paperWidthMm,
                          decoration: const InputDecoration(
                            labelText: 'Paper width',
                          ),
                          items: [
                            for (final width in (supportedPaperWidthsMm.toList()
                              ..sort()))
                              DropdownMenuItem(
                                value: width,
                                child: Text('$width mm'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _paperWidthMm = value);
                            _schedulePreviewRefresh();
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<PrintMode>(
                          value: _mode,
                          decoration: const InputDecoration(labelText: 'Print mode'),
                          items: PrintMode.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(m.name),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _mode = value);
                              _schedulePreviewRefresh();
                            }
                          },
                        ),
                        if (_mode == PrintMode.template) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedTemplate,
                            decoration: const InputDecoration(labelText: 'Template'),
                            items: const [
                              DropdownMenuItem(
                                value: 'kitchen_kot_80',
                                child: Text('kitchen_kot_80'),
                              ),
                              DropdownMenuItem(
                                value: 'invoice_80',
                                child: Text('invoice_80'),
                              ),
                              DropdownMenuItem(
                                value: 'tamil_check_80',
                                child: Text('tamil_check_80 (Tamil)'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedTemplate = value);
                                _schedulePreviewRefresh();
                              }
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _print,
                          icon: const Icon(Icons.print),
                          label: const Text('Execute Print Job'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last job', style: textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Job ID: ${_lastJobId ?? '-'}'),
                        Text('Status: ${_lastResult?.status.name ?? '-'}'),
                        if (_lastResult?.errorMessage != null)
                          Text(
                            'Error: ${_lastResult!.errorMessage}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_logs.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Live logs', style: textTheme.titleMedium),
                          const SizedBox(height: 8),
                          ..._logs.take(10).map(
                            (log) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                '[${log.step}] ${log.message}',
                                style: textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PayloadPreviewPanel(
              expanded: _previewExpanded,
              loading: _previewLoading,
              dartCode: _previewDart,
              jsonCode: _previewJson,
              hexCode: _previewHex,
              selectedTab: _previewTab,
              onToggleExpanded: _togglePreviewExpanded,
              onRefresh: _refreshPreview,
              onTabChanged: (tab) => setState(() => _previewTab = tab),
              onCopy: _copyPreview,
            ),
          ],
        ),
      ),
    );
  }
}
