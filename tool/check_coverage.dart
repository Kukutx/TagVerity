import 'dart:io';

void main(List<String> args) {
  final String path = args.isEmpty ? 'coverage/lcov.info' : args.first;
  final double minimum = args.length < 2 ? 75 : double.parse(args[1]);
  final File file = File(path);
  if (!file.existsSync()) {
    _fail('Coverage file not found: $path');
  }

  int found = 0;
  int total = 0;
  for (final String line in file.readAsLinesSync()) {
    if (line.startsWith('LH:')) {
      found += int.parse(line.substring(3));
    } else if (line.startsWith('LF:')) {
      total += int.parse(line.substring(3));
    }
  }
  if (total == 0) {
    _fail('Coverage report contains no executable lines.');
  }

  final double percent = found * 100 / total;
  stdout.writeln(
    'Line coverage: $found/$total = ${percent.toStringAsFixed(1)}% '
    '(minimum ${minimum.toStringAsFixed(1)}%)',
  );
  if (percent + 1e-9 < minimum) {
    _fail('Line coverage is below the required minimum.');
  }
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
