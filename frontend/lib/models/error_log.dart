class ErrorLog {
  final int? id;
  final String user;
  final String logLevel;
  final String module;
  final String action;
  final String message;
  final String deviceInfo;
  final String stackTrace;
  final DateTime timestamp;

  ErrorLog({
    this.id,
    required this.user,
    required this.logLevel,
    required this.module,
    required this.action,
    required this.message,
    required this.deviceInfo,
    required this.stackTrace,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user': user,
      'log_level': logLevel,
      'module': module,
      'action': action,
      'message': message,
      'device_info': deviceInfo,
      'stack_trace': stackTrace,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ErrorLog.fromMap(Map<String, dynamic> map) {
    return ErrorLog(
      id: map['id'],
      user: map['user'],
      logLevel: map['log_level'],
      module: map['module'],
      action: map['action'],
      message: map['message'],
      deviceInfo: map['device_info'],
      stackTrace: map['stack_trace'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
