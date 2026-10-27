import '../database/database_helper.dart';

class ActivityService {
  ActivityService._();

  static final ActivityService instance = ActivityService._();

  final _database = DatabaseHelper.instance;

  Future<void> recordCalculationCompleted({
    required int userId,
    required double totalEmission,
  }) {
    final eventToken = DateTime.now().toUtc().microsecondsSinceEpoch;
    return _database.recordActivity(
      userId: userId,
      eventType: 'calculation_completed',
      details: 'Estimated ${totalEmission.toStringAsFixed(2)} tCO2e/year.',
      dedupeKey: 'calculation-completed:$userId:$eventToken',
    );
  }
}
