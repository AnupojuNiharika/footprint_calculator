import 'package:flutter_test/flutter_test.dart';
import 'package:footprint_calculator/database/database_helper.dart';
import 'package:footprint_calculator/models/carbon_calculation.dart';
import 'package:footprint_calculator/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('database persists a calculation across inserts and reads', () async {
    final db = DatabaseHelper.instance;
    final testDatabase = await db.database;
    await testDatabase.delete('activity_logs');
    await testDatabase.delete('carbon_calculations');
    await testDatabase.delete('users');

    final userId = await db.insertUser(
      name: 'Calculation Owner',
      email:
          'calculation-owner-${DateTime.now().microsecondsSinceEpoch}@example.test',
      passwordSalt: 'test-salt',
      passwordHash: 'test-hash',
    );
    await SharedPreferencesAsync().setInt('lumen.session.user_id', userId);
    expect(await db.promoteFirstAdmin(userId), isTrue);

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

    final id = await testDatabase.insert('carbon_calculations', item.toMap());
    final ownedItem = CarbonCalculation(
      userId: userId,
      date: '2026-10-07T10:15:00.000Z',
      transportEmission: 1.2,
      electricityEmission: 2.3,
      foodEmission: 3.4,
      travelEmission: 1.2,
      totalEmission: 6.9,
    );
    final ownedId = await db.saveCalculation(ownedItem);
    final records = await db.getAllCalculations(userId: userId);

    expect(id, isNonZero);
    expect(ownedId, isNonZero);
    expect(records, hasLength(1));
    expect(records.single.totalEmission, closeTo(6.9, 0.0001));
    expect(await db.getCalculationCount(), greaterThanOrEqualTo(1));
    expect(await db.getTotalEmissions(), closeTo(18.3, 0.0001));
    expect(await db.getActivityCount(), greaterThanOrEqualTo(2));
    expect(
      (await db.getAdminCalculationRows()).singleWhere(
        (row) => row['id'] == ownedId,
      )['user_id'],
      userId,
    );
    expect(
      (await db.getAdminActivityRows()).any(
        (activity) =>
            activity.eventType == 'calculation_saved' &&
            activity.userId == userId,
      ),
      isTrue,
    );
  });

  test(
    'new accounts default to USER and admin listing omits credentials',
    () async {
      final db = DatabaseHelper.instance;
      final email =
          'admin-list-${DateTime.now().microsecondsSinceEpoch}@example.test';

      final id = await db.insertUser(
        name: 'Lumen Test',
        email: email,
        passwordSalt: 'not-a-real-salt',
        passwordHash: 'not-a-real-hash',
      );
      final user = await db.getUserById(id);
      expect(user?['role'], 'USER');
      expect(user?['created_at'], isA<String>());

      await SharedPreferencesAsync().setInt('lumen.session.user_id', id);
      await expectLater(
        db.getAdminDashboardUsers(),
        throwsA(isA<StateError>()),
      );
      await expectLater(db.getUserCount(), throwsA(isA<StateError>()));
      final otherUsersCalculation = await db.database.then(
        (database) => database.query(
          'carbon_calculations',
          columns: ['id'],
          where: 'user_id != ?',
          whereArgs: [id],
          limit: 1,
        ),
      );
      if (otherUsersCalculation.isNotEmpty) {
        await expectLater(
          db.deleteCalculation(
            otherUsersCalculation.first['id'] as int,
            userId: id,
          ),
          completion(0),
        );
      }
      await expectLater(
        AuthService.instance.loadAdminDashboard(),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            'You are not authorized to view this page.',
          ),
        ),
      );
    },
  );

  test(
    'registration, login, and logout activity is stored on success',
    () async {
      final auth = AuthService.instance;
      await SharedPreferencesAsync().remove('lumen.session.user_id');
      final email =
          'auth-flow-${DateTime.now().microsecondsSinceEpoch}@example.test';

      await auth.register(
        name: 'Auth Flow',
        email: email,
        password: 'secure-test-password',
      );
      final registered = await DatabaseHelper.instance.getUserByEmail(email);
      expect(registered?['role'], 'USER');
      await expectLater(
        auth.register(
          name: 'Auth Flow',
          email: email,
          password: 'secure-test-password',
        ),
        throwsA(isA<AuthException>()),
      );
      await expectLater(
        auth.signIn(email: email, password: 'not-the-password'),
        throwsA(isA<AuthException>()),
      );

      final signedIn = await auth.signIn(
        email: email,
        password: 'secure-test-password',
      );
      expect(signedIn.isAdmin, isFalse);
      expect(await auth.restoreSession(), isNotNull);
      await auth.signOut();
      expect(await auth.restoreSession(), isNull);

      final events = await (await DatabaseHelper.instance.database).query(
        'activity_logs',
        columns: ['event_type'],
        where: 'user_id = ?',
        whereArgs: [signedIn.id],
      );
      expect(
        events.map((event) => event['event_type']),
        unorderedEquals([
          'registration_succeeded',
          'login_succeeded',
          'logout',
        ]),
      );
    },
  );

  test('admin dashboard derives totals and records from stored rows', () async {
    final db = DatabaseHelper.instance;
    final testDatabase = await db.database;
    await testDatabase.delete('activity_logs');
    await testDatabase.delete('carbon_calculations');
    await testDatabase.delete('users');
    final adminId = await db.insertUser(
      name: 'Dashboard Admin',
      email:
          'dashboard-admin-${DateTime.now().microsecondsSinceEpoch}@example.test',
      passwordSalt: 'test-salt',
      passwordHash: 'test-hash',
    );
    await SharedPreferencesAsync().setInt('lumen.session.user_id', adminId);
    expect(await db.promoteFirstAdmin(adminId), isTrue);
    final calculationId = await db.saveCalculation(
      CarbonCalculation(
        userId: adminId,
        date: DateTime.now().toUtc().toIso8601String(),
        transportEmission: 1,
        electricityEmission: 2,
        foodEmission: 3,
        travelEmission: 1,
        totalEmission: 6,
      ),
    );
    await SharedPreferencesAsync().setInt('lumen.session.user_id', adminId);

    final dashboard = await AuthService.instance.loadAdminDashboard();
    final visibleUsers = await db.getAdminDashboardUsers();
    final savedCalculation = dashboard.calculations.singleWhere(
      (record) => record.calculation.id == calculationId,
    );
    final visibleAdmin = visibleUsers.singleWhere(
      (row) => row['id'] == adminId,
    );

    expect(dashboard.databaseAccessible, isTrue);
    expect(dashboard.userCount, 1);
    expect(dashboard.adminCount, 1);
    expect(dashboard.calculationCount, 1);
    expect(dashboard.activityCount, 3);
    expect(dashboard.totalEmissions, 6);
    expect(visibleAdmin['password_salt'], isNull);
    expect(visibleAdmin['password_hash'], isNull);
    expect(savedCalculation.userName, 'Dashboard Admin');
    expect(savedCalculation.userEmail, contains('dashboard-admin-'));
    expect(
      dashboard.users
          .where((user) => user.email == savedCalculation.userEmail)
          .length,
      1,
    );
    expect(
      dashboard.activities.any(
        (activity) => activity.eventType == 'admin_setup',
      ),
      isTrue,
    );
    expect(
      dashboard.users.any(
        (user) => user.name == 'Dashboard Admin' && user.isAdmin,
      ),
      isTrue,
    );
  });
}
