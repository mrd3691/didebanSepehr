import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dideban_sepehr/main.dart';
import 'package:dideban_sepehr/models.dart';
import 'package:dideban_sepehr/tracking_screen.dart';

void main() {
  testWidgets(
    'Server setup is shown once and persists separately from session',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(const DidebanApp());
      await tester.pumpAndSettle();
      expect(find.text('Set up your server'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        'http://37.202.178.136:8082/',
      );
      await tester.ensureVisible(find.text('Save and continue'));
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your server'), findsNothing);
      expect(find.text('Username'), findsOneWidget);
      expect(
        await const FlutterSecureStorage().read(key: 'server'),
        'http://37.202.178.136:8082/',
      );
      expect(await const FlutterSecureStorage().read(key: 'session'), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const DidebanApp());
      await tester.pumpAndSettle();
      expect(find.text('Set up your server'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Set up your server'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );

  testWidgets('Login validates inputs before calling server', (tester) async {
    var called = false;
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          server: 'https://gps.example.com',
          onLogin: (a, b, c, d) async {
            called = true;
          },
        ),
      ),
    );
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(called, false);
    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('Login passes values and renders failures', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          server: 'https://gps.example.com',
          onLogin: (url, user, password, remember) async {
            expect(url, 'https://gps.example.com');
            expect(user, 'driver');
            expect(password, 'a&b+c');
            expect(remember, true);
            throw Exception('network');
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'driver');
    await tester.enterText(find.byType(TextFormField).at(1), 'a&b+c');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in failed. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tracking rejects reversed date range', (tester) async {
    final now = DateTime(2026, 10, 19, 8);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RouteFilter(
            devices: [
              Device.fromJson({'id': 7, 'name': 'Sepehr 07'}),
            ],
            deviceId: 7,
            from: now,
            to: now.subtract(const Duration(days: 1)),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Load route'));
    await tester.tap(find.text('Load route'));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter valid dates and times. Start must be before end.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
