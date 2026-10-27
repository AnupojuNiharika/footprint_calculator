// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:footprint_calculator/main.dart';
import 'package:footprint_calculator/services/auth_service.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  testWidgets('login and registration pages link to each other', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthPage(onAuthenticated: (_) {})),
    );

    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    expect(find.text('Make it count.'), findsOneWidget);
    expect(find.byKey(const ValueKey('register-name')), findsOneWidget);
    await tester.ensureVisible(find.text('Already have an account? Log in'));
    await tester.tap(find.text('Already have an account? Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
  });

  testWidgets('unauthenticated users are rejected by direct admin navigation', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardPage()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in with an administrator account.'), findsOneWidget);
    await AuthService.instance.signOut();
    await expectLater(
      AuthService.instance.loadAdminDashboard(),
      throwsA(isA<AuthException>()),
    );
  });

  testWidgets('startup splash transitions to login when no session exists', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const CarbonApp());
    expect(find.text('Carbon Companion'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
  });
}
