import 'agent_build_stub.dart';

Future<AgentDownloadResult> downloadPrintHubPackage({
  String? agentBaseUrl,
}) async {
  return const AgentDownloadResult(
    success: false,
    message: 'Download is only available from the web app in a browser.',
  );
}
