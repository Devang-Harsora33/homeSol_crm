class ActivityLog {
  final String? versionId;
  final String? user;
  final String? timestamp;
  final String? type;
  final String? message;

  ActivityLog({
    this.versionId,
    this.user,
    this.timestamp,
    this.type,
    this.message,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      versionId: json['version_id'],
      user: json['user'],
      timestamp: json['timestamp'],
      type: json['type'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version_id': versionId,
      'user': user,
      'timestamp': timestamp,
      'type': type,
      'message': message,
    };
  }
}
