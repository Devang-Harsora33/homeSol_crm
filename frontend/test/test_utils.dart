import 'dart:io';

class TestLogger {
  static final File _logFile = File('test_results.log');

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message\n';
    print(message); // Still print to console
    _logFile.writeAsStringSync(logMessage, mode: FileMode.append);
  }

  static void clear() {
    if (_logFile.existsSync()) {
      _logFile.deleteSync();
    }
  }
}
