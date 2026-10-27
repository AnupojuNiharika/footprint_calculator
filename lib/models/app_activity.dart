class AppActivity {
  const AppActivity({
    required this.id,
    required this.eventType,
    required this.occurredAt,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.details,
  });

  final int id;
  final String eventType;
  final DateTime? occurredAt;
  final int? userId;
  final String? userName;
  final String? userEmail;
  final String? details;

  factory AppActivity.fromMap(Map<String, Object?> row) {
    final occurredAt = row['occurred_at'] as String?;
    return AppActivity(
      id: row['id'] as int,
      eventType: row['event_type'] as String,
      occurredAt: occurredAt == null ? null : DateTime.tryParse(occurredAt),
      userId: row['user_id'] as int?,
      userName: row['user_name'] as String?,
      userEmail: row['user_email'] as String?,
      details: row['details'] as String?,
    );
  }
}
