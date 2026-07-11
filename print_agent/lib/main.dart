import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'print_agent_server.dart';

Future<void> _writeHubUrlSnapshot(PrintAgentServer server) async {
  if (!Platform.isWindows) return;

  try {
    final dir = Directory(r'C:\ProgramData\PrintWorkerHub');
    await dir.create(recursive: true);
    final file = File('${dir.path}${Platform.pathSeparator}hub-url.txt');
    await file.writeAsString(
      'updated=${DateTime.now().toIso8601String()}\n'
      'local=${server.localHubUrl}\n'
      'lan=${server.lanHubUrl ?? ''}\n'
      'web=${server.recommendedWebUrl}\n',
    );
  } catch (_) {}
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  final headless = args.contains('--headless');
  final server = PrintAgentServer();
  await server.start();
  await _writeHubUrlSnapshot(server);

  if (headless) {
    runApp(HeadlessHubApp(server: server));
    return;
  }

  runApp(PrintAgentApp(server: server));
}

/// Background hub for Windows boot task / service (HTTP only).
class HeadlessHubApp extends StatelessWidget {
  const HeadlessHubApp({super.key, required this.server});

  final PrintAgentServer server;

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: SizedBox.shrink());
  }
}

class PrintAgentApp extends StatelessWidget {
  const PrintAgentApp({super.key, required this.server});

  final PrintAgentServer server;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Print Worker Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: PrintAgentPage(server: server),
    );
  }
}

class PrintAgentPage extends StatefulWidget {
  const PrintAgentPage({super.key, required this.server});

  final PrintAgentServer server;

  @override
  State<PrintAgentPage> createState() => _PrintAgentPageState();
}

class _PrintAgentPageState extends State<PrintAgentPage> {
  final List<String> _logs = [];
  List<String> _printers = [];
  List<Map<String, String>> _bluetoothDevices = [];
  bool _loadingPrinters = true;

  @override
  void initState() {
    super.initState();
    widget.server.logs.listen((line) {
      if (!mounted) return;
      setState(() {
        _logs.insert(0, line);
        if (_logs.length > 80) _logs.removeLast();
      });
    });
    _refreshPrinters();
  }

  Future<void> _refreshPrinters() async {
    setState(() => _loadingPrinters = true);
    final printers = await widget.server.listLocalPrinters();
    final bluetooth = await widget.server.listBluetoothDevices();
    if (!mounted) return;
    setState(() {
      _printers = printers;
      _bluetoothDevices = bluetooth;
      _loadingPrinters = false;
    });
  }

  Future<void> _copyText(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lanUrl = widget.server.lanHubUrl;
    final localUrl = widget.server.localHubUrl;
    final webUrl = widget.server.recommendedWebUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Worker Hub'),
        actions: [
          IconButton(
            onPressed: _loadingPrinters ? null : _refreshPrinters,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh printers & Bluetooth',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Hub service running',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Paste this URL in your hosted web app settings:',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (lanUrl != null) ...[
                    Text(
                      'Shop LAN IP (tablets / other PCs on Wi‑Fi)',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      lanUrl,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _copyText(lanUrl, 'LAN URL'),
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy LAN URL'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    'This PC only (Chrome on same machine)',
                    style: theme.textTheme.labelMedium,
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    localUrl,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copyText(localUrl, 'Local URL'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy local URL'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recommended for web app', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        SelectableText(
                          webUrl,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
                  Text(
                    'Also saved to C:\\ProgramData\\PrintWorkerHub\\hub-url.txt',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Text('USB printers on this PC', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingPrinters)
            const LinearProgressIndicator()
          else if (_printers.isEmpty)
            Text(
              'No printers found. Install the printer driver in Windows, '
              'then click Refresh.',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            ..._printers.map(
              (name) => ListTile(
                leading: const Icon(Icons.print),
                title: Text(name),
                dense: true,
              ),
            ),
          const SizedBox(height: 16),
          Text('Paired Bluetooth devices', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_loadingPrinters)
            const SizedBox.shrink()
          else if (_bluetoothDevices.isEmpty)
            Text(
              'No paired Bluetooth devices found. Pair the printer in Windows '
              'Settings, then click Refresh.',
              style: TextStyle(color: theme.colorScheme.error),
            )
          else
            ..._bluetoothDevices.map(
              (device) => ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(device['name'] ?? 'Bluetooth device'),
                subtitle: Text(device['address'] ?? ''),
                dense: true,
              ),
            ),
          const SizedBox(height: 16),
          Text('API', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('GET  /health'),
          const Text('GET  /printers'),
          const Text('GET  /bluetooth'),
          const Text('GET  /download/hub'),
          const Text('POST /print  { "printer": "...", "bytes": "<base64>" }'),
          const Text(
            'POST /print  { "transport": "bluetooth", "address": "...", "bytes": "..." }',
          ),
          const SizedBox(height: 16),
          Text('Activity log', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._logs.take(20).map(
            (line) => Text(
              line,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
