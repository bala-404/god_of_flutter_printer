import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'agent_build_stub.dart' show AgentBuildResult, AgentDownloadResult;
import 'agent_build_stub.dart' as agent_build
    if (dart.library.io) 'agent_build_io.dart';
import 'hub_download_stub.dart'
    if (dart.library.html) 'hub_download_web.dart' as hub_download;

/// Developer tools: build or download Print Hub for shop PCs.
class DeveloperHubPage extends StatefulWidget {
  const DeveloperHubPage({super.key});

  @override
  State<DeveloperHubPage> createState() => _DeveloperHubPageState();
}

class _DeveloperHubPageState extends State<DeveloperHubPage> {
  final _hubUrlController = TextEditingController(
    text: 'http://localhost:9280',
  );

  bool _busy = false;
  AgentBuildResult? _buildResult;
  AgentDownloadResult? _downloadResult;

  @override
  void dispose() {
    _hubUrlController.dispose();
    super.dispose();
  }

  Future<void> _runBuild() async {
    setState(() {
      _busy = true;
      _buildResult = null;
      _downloadResult = null;
    });

    final result = await agent_build.buildPrintHubExe();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _buildResult = result;
    });
  }

  Future<void> _runDownload() async {
    setState(() {
      _busy = true;
      _downloadResult = null;
      _buildResult = null;
    });

    final result = await hub_download.downloadPrintHubPackage(
      agentBaseUrl: _hubUrlController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _busy = false;
      _downloadResult = result;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started')),
      );
    }
  }

  Future<void> _openFolder() async {
    final folder = _buildResult?.releaseFolder;
    if (folder == null) return;
    if (!kIsWeb) {
      await agent_build.openReleaseFolder(folder);
    }
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildResult = _buildResult;
    final downloadResult = _downloadResult;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer — Print Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Package integration', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Add print_worker to your Flutter web app.\n'
                    '2. Call PrintWorker.instance.execute() with your payload.\n'
                    '3. Install Print Hub once on each shop counter PC.\n'
                    '4. Paste the hub LAN URL into your web app settings.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    kIsWeb
                        ? 'Download Print Hub (for shop PCs)'
                        : 'Build Print Hub EXE (for shop PCs)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb
                        ? 'Browsers cannot compile Windows apps. Download the '
                            'pre-built zip from a running hub on this PC '
                            '(after package_release.ps1 was run once on Windows).'
                        : 'Runs package_release.ps1: builds EXE + zip with '
                            'install_hub.bat (auto-start on every boot).',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _hubUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Hub URL for download',
                        hintText: 'http://localhost:9280',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : (kIsWeb ? _runDownload : _runBuild),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(kIsWeb ? Icons.download : Icons.build),
                    label: Text(
                      _busy
                          ? (kIsWeb ? 'Preparing download…' : 'Building…')
                          : (kIsWeb
                              ? 'Download Print Hub for Windows'
                              : 'Generate Print Hub package'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _copy(
                      kIsWeb
                          ? 'cd print_agent\n.\\scripts\\package_release.ps1'
                          : 'cd print_agent\nflutter build windows --release',
                    ),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(
                      kIsWeb ? 'Copy package script' : 'Copy build commands',
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (downloadResult != null) ...[
            const SizedBox(height: 12),
            _resultCard(
              theme: theme,
              success: downloadResult.success,
              title: downloadResult.success
                  ? 'Download started'
                  : 'Download not available',
              body: downloadResult.message,
              successColor: Colors.green.shade700,
            ),
          ],
          if (buildResult != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          buildResult.success
                              ? Icons.check_circle
                              : Icons.error_outline,
                          color: buildResult.success
                              ? Colors.green.shade700
                              : theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          buildResult.success ? 'Build complete' : 'Build failed',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    if (buildResult.zipPath != null) ...[
                      const SizedBox(height: 12),
                      Text('Installer ZIP', style: theme.textTheme.labelLarge),
                      SelectableText(
                        buildResult.zipPath!,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: kIsWeb
                            ? null
                            : () => agent_build.openZipFolder(buildResult.zipPath!),
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open dist folder'),
                      ),
                    ],
                    if (buildResult.releaseFolder != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: kIsWeb ? null : _openFolder,
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Open Release folder'),
                      ),
                    ],
                    if (buildResult.error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        buildResult.error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    if (buildResult.log.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Log', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 4),
                      SelectableText(
                        buildResult.log,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('After shop install', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'After shop install (install_hub.bat as Administrator):\n\n'
                    '• Hub auto-starts when the shop user logs on to Windows\n'
                    '• Runs as that user so paired Bluetooth printers work\n'
                    '• LAN URL: open desktop shortcut "Print Worker Hub"\n'
                    '• Or read C:\\ProgramData\\PrintWorkerHub\\hub-url.txt\n\n'
                    'Paste the LAN URL into your web app Print hub URL field.',
                  ),
                  const SizedBox(height: 12),
                  Text('Windows package script', style: theme.textTheme.labelLarge),
                  SelectableText(
                    agent_build.printHubPackageScriptPath,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard({
    required ThemeData theme,
    required bool success,
    required String title,
    required String body,
    required Color successColor,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.info_outline,
                  color: success ? successColor : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(body),
          ],
        ),
      ),
    );
  }
}
