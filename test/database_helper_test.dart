import 'package:flutter_test/flutter_test.dart';
import 'package:footprint_calculator/database/database_helper.dart';
import 'package:footprint_calculator/models/carbon_calculation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('database persists a calculation across inserts and reads', () async {
    final db = DatabaseHelper.instance;
    await db.clearAll();

    final item = CarbonCalculation(
      date: '2026-10-07',
      transportEmission: 1.2,
      electricityEmission: 2.3,
      foodEmission: 3.4,
      travelEmission: 4.5,
      totalEmission: 11.4,
      transportDistance: 10,
      electricityUnits: 150,
      foodType: 'mixed',
      travelDistance: 35,
      travelType: 'train',
    );

    final id = await db.insertCalculation(item);
    final records = await db.getAllCalculations();

    expect(id, isNonZero);
    expect(records, isNotEmpty);
    expect(records.first.totalEmission, closeTo(11.4, 0.0001));
  });
}
