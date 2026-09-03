import 'dart:convert';
import 'dart:io';

const String _requiredFlutterVersion = '3.47.1';
const String _requiredDartVersion = '3.13.1';

Future<void> main(List<String> arguments) async {
  final bool skipChecks = arguments.contains('--skip-checks');
  final Directory root = _locateProjectRoot();

  stdout.writeln('Project: ${root.path}');
  await _requireSingleLocalSdk(root);
  _requireCommittedPlatforms(root);

  await _run(
    _flutterExecutable,
    const <String>['pub', 'get'],
    root,
    description: 'flutter pub get',
  );
  await _run(
    _dartExecutable,
    const <String>['format', 'lib', 'test', 'tool'],
    root,
    description: 'dart format',
  );

  if (!skipChecks) {
    await _run(
      _flutterExecutable,
      const <String>['analyze'],
      root,
      description: 'flutter analyze',
    );
    await _run(
      _flutterExecutable,
      const <String>['test'],
      root,
      description: 'flutter test',
    );
  }

  stdout.writeln('\nTagVerity setup verified with the existing local SDK.');
}

Directory _locateProjectRoot() {
  Directory candidate = Directory.current.absolute;
  if (File(_join(candidate.path, 'pubspec.yaml')).existsSync()) {
    return candidate;
  }

  candidate = File.fromUri(Platform.script).parent.parent.absolute;
  if (File(_join(candidate.path, 'pubspec.yaml')).existsSync()) {
    return candidate;
  }

  throw StateError(
    'Could not locate the project root containing pubspec.yaml.',
  );
}

String get _flutterExecutable => Platform.isWindows ? 'flutter.bat' : 'flutter';
String get _dartExecutable => Platform.isWindows ? 'dart.bat' : 'dart';

Future<void> _requireSingleLocalSdk(Directory root) async {
  final ProcessResult versionResult = await _runProcess(
    _flutterExecutable,
    const <String>['--version'],
    root,
  );
  final String output = '${versionResult.stdout}\n${versionResult.stderr}';
  stdout.writeln(output.trim());
  if (versionResult.exitCode != 0) {
    throw StateError('The configured Flutter SDK could not start.');
  }
  if (!output.contains('Flutter $_requiredFlutterVersion') ||
      !output.contains('Dart $_requiredDartVersion')) {
    throw StateError(
      'TagVerity requires the existing Flutter $_requiredFlutterVersion / '
      'Dart $_requiredDartVersion SDK.',
    );
  }

  if (!Platform.isWindows) {
    return;
  }

  final Set<String> flutterBins = await _windowsExecutableBins('flutter');
  final Set<String> dartBins = await _windowsExecutableBins('dart');
  if (flutterBins.length != 1) {
    throw StateError(
      'Multiple Flutter SDK locations are active on PATH: ${flutterBins.join(', ')}',
    );
  }
  if (dartBins.length != 1) {
    throw StateError(
      'Multiple Dart SDK locations are active on PATH: ${dartBins.join(', ')}',
    );
  }

  final String flutterBin = flutterBins.single.toLowerCase();
  final String dartBin = dartBins.single.toLowerCase();
  final String expectedDartBin = _join(
    flutterBin,
    'cache${Platform.pathSeparator}dart-sdk${Platform.pathSeparator}bin',
  ).toLowerCase();
  if (dartBin != flutterBin && dartBin != expectedDartBin) {
    throw StateError(
      'Dart is not coming from the active Flutter SDK. Flutter: $flutterBin; Dart: $dartBin',
    );
  }
}

Future<Set<String>> _windowsExecutableBins(String executable) async {
  final ProcessResult result = await Process.run('where.exe', <String>[
    executable,
  ], runInShell: false);
  if (result.exitCode != 0) {
    throw StateError('$executable was not found on PATH.');
  }
  return LineSplitter.split(result.stdout.toString())
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .map((String path) => File(path).parent.absolute.path)
      .toSet();
}

void _requireCommittedPlatforms(Directory root) {
  for (final String directory in <String>['android', 'ios']) {
    if (!Directory(_join(root.path, directory)).existsSync()) {
      throw StateError(
        '$directory/ is missing. TagVerity keeps store platform projects committed.',
      );
    }
  }
}

Future<void> _run(
  String executable,
  List<String> arguments,
  Directory root, {
  required String description,
}) async {
  stdout.writeln('\n> $description');
  final ProcessResult result = await _runProcess(executable, arguments, root);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    throw StateError('$description failed with exit ${result.exitCode}.');
  }
}

Future<ProcessResult> _runProcess(
  String executable,
  List<String> arguments,
  Directory root,
) {
  if (Platform.isWindows && executable.toLowerCase().endsWith('.bat')) {
    return Process.run(
      'cmd.exe',
      <String>['/d', '/c', executable, ...arguments],
      workingDirectory: root.path,
      runInShell: false,
    );
  }
  return Process.run(
    executable,
    arguments,
    workingDirectory: root.path,
    runInShell: false,
  );
}

String _join(String first, String second) {
  final String separator = Platform.pathSeparator;
  return first.endsWith(separator)
      ? '$first$second'
      : '$first$separator$second';
}
