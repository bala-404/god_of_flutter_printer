import 'dart:io';

import 'agent_build_stub.dart' show AgentBuildResult;
export 'agent_build_stub.dart'
    show AgentBuildResult, printHubBuildScriptPath, printHubPackageScriptPath;

Future<String?> _resolvePrintAgentDir() async {
  const candidates = [
    '../print_agent',
    'print_agent',
  ];

  for (final relative in candidates) {
    final dir = Directory(relative);
    final pubspec = File('${dir.path}/pubspec.yaml');
    if (await pubspec.exists()) {
      return dir.absolute.path;
    }
  }

  var current = Directory.current.absolute;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = Directory('${current.path}${Platform.pathSeparator}print_agent');
    if (await File('${candidate.path}${Platform.pathSeparator}pubspec.yaml')
        .exists()) {
      return candidate.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }

  return null;
}

/// Builds release EXE + zip installer package (runs package_release.ps1).
Future<AgentBuildResult> buildPrintHubExe() async {
  if (!Platform.isWindows) {
    return const AgentBuildResult(
      supported: false,
      log: '',
      error: 'Print Hub package can only be built on Windows with Flutter installed.',
    );
  }

  final agentDir = await _resolvePrintAgentDir();
  if (agentDir == null) {
    return const AgentBuildResult(
      supported: true,
      log: '',
      error:
          'Could not find the print_agent folder.\n'
          'Open the print_worker repo and run the example from there.',
    );
  }

  final buffer = StringBuffer()
    ..writeln('Building Print Hub package...')
    ..writeln('Source: $agentDir')
    ..writeln('');

  final packageScript =
      '$agentDir${Platform.pathSeparator}scripts${Platform.pathSeparator}package_release.ps1';

  try {
    final build = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', packageScript],
      workingDirectory: agentDir,
      runInShell: true,
    );

    buffer
      ..writeln(build.stdout)
      ..writeln(build.stderr);

    final releaseDir =
        '$agentDir${Platform.pathSeparator}build${Platform.pathSeparator}'
        'windows${Platform.pathSeparator}x64${Platform.pathSeparator}'
        'runner${Platform.pathSeparator}Release';
    final exePath =
        '$releaseDir${Platform.pathSeparator}print_agent.exe';
    final zipPath =
        '$agentDir${Platform.pathSeparator}dist${Platform.pathSeparator}'
        'PrintWorkerHub-win64.zip';

    if (build.exitCode != 0) {
      return AgentBuildResult(
        supported: true,
        log: buffer.toString(),
        error: 'package_release.ps1 failed (exit ${build.exitCode}).',
      );
    }

    if (!await File(exePath).exists()) {
      return AgentBuildResult(
        supported: true,
        log: buffer.toString(),
        error: 'Build finished but print_agent.exe was not found.',
      );
    }

    if (!await File(zipPath).exists()) {
      return AgentBuildResult(
        supported: true,
        log: buffer.toString(),
        error: 'Build finished but PrintWorkerHub-win64.zip was not found.',
      );
    }

    buffer
      ..writeln('')
      ..writeln('Success!')
      ..writeln('ZIP (ship to shops): $zipPath')
      ..writeln('EXE: $exePath')
      ..writeln('')
      ..writeln('Shop install: unzip -> Run install_hub.bat as Administrator')
      ..writeln('Hub auto-starts on every Windows boot after install.');

    return AgentBuildResult(
      supported: true,
      success: true,
      log: buffer.toString(),
      exePath: exePath,
      releaseFolder: releaseDir,
      zipPath: zipPath,
    );
  } catch (error) {
    return AgentBuildResult(
      supported: true,
      log: buffer.toString(),
      error: error.toString(),
    );
  }
}

Future<void> openReleaseFolder(String folderPath) async {
  if (!Platform.isWindows) return;
  await Process.run('explorer', [folderPath], runInShell: true);
}

Future<void> openZipFolder(String zipPath) async {
  if (!Platform.isWindows) return;
  final dir = File(zipPath).parent.path;
  await Process.run('explorer', [dir], runInShell: true);
}
