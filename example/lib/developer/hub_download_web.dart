import 'dart:convert';
import 'dart:html' as html;

import 'package:http/http.dart' as http;
import 'package:god_of_flutter_printer/god_of_flutter_printer.dart';

import 'agent_build_stub.dart';

/// Triggers browser download of the Print Hub zip from a running local hub.
Future<AgentDownloadResult> downloadPrintHubPackage({
  String? agentBaseUrl,
}) async {
  final candidates = PrintAgentClient.candidateBaseUrls(preferred: agentBaseUrl);

  for (final base in candidates) {
    try {
      final health = await http
          .get(Uri.parse('$base/health'))
          .timeout(const Duration(seconds: 4));

      if (health.statusCode != 200) continue;

      final json = jsonDecode(health.body) as Map<String, dynamic>;
      if (json['hubPackage'] != true) {
        return const AgentDownloadResult(
          success: false,
          message:
              'Print Hub is running but the zip package is not built yet.\n\n'
              'On this Windows PC, run once in a terminal:\n'
              '  cd print_agent\n'
              '  .\\scripts\\package_release.ps1\n\n'
              'Then tap Download again.',
        );
      }

      final downloadUrl = '$base/download/hub';
      html.AnchorElement(href: downloadUrl)
        ..download = 'PrintWorkerHub-win64.zip'
        ..click();

      return AgentDownloadResult(
        success: true,
        message:
            'Download started from $downloadUrl\n\n'
            'Unzip on the shop PC and run print_agent.exe. '
            'Copy the LAN URL from the hub window into your web app.',
        sourceUrl: downloadUrl,
      );
    } catch (_) {
      continue;
    }
  }

  return const AgentDownloadResult(
    success: false,
    message:
        'Cannot reach Print Hub on this PC.\n\n'
        '1. Start the hub: cd print_agent && flutter run -d windows\n'
        '2. Build the zip once: .\\scripts\\package_release.ps1\n'
        '3. Return here and tap Download Print Hub for Windows',
  );
}
