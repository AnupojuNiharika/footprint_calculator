// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:footprint_calculator/main.dart';

void main() {
  testWidgets('login and registration pages link to each other', (WidgetTester tester) async {
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
}
