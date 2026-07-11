/// Result of building the Print Hub Windows release on a dev machine.
class AgentBuildResult {
  const AgentBuildResult({
    required this.supported,
    required this.log,
    this.success = false,
    this.exePath,
    this.releaseFolder,
    this.zipPath,
    this.error,
  });

  final bool supported;
  final bool success;
  final String log;
  final String? exePath;
  final String? releaseFolder;
  final String? zipPath;
  final String? error;
}

/// Result of downloading a pre-built Print Hub package (web).
class AgentDownloadResult {
  const AgentDownloadResult({
    required this.success,
    required this.message,
    this.sourceUrl,
  });

  final bool success;
  final String message;
  final String? sourceUrl;
}

Future<AgentBuildResult> buildPrintHubExe() async {
  return const AgentBuildResult(
    supported: false,
    log: '',
    error: 'Use Download Print Hub on web, or open this page in the Windows app to build.',
  );
}

const String printHubBuildScriptPath = 'print_agent/scripts/build_release.ps1';
const String printHubPackageScriptPath = 'print_agent/scripts/package_release.ps1';

Future<void> openReleaseFolder(String folderPath) async {}
Future<void> openZipFolder(String zipPath) async {}
