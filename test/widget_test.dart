// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import 'package:flutter_test/flutter_test.dart';
import 'package:mediciapp/main.dart';
import 'package:mediciapp/providers/year_service_provider.dart'; // Import the provider
import 'package:mediciapp/services/year_service.dart'; // Import YearService

void main() {
  testWidgets('App loads and displays Analysis tab', (
    WidgetTester tester,
  ) async {
    // Initialize the YearService for the test.
    // Using await YearService.create() ensures it's properly initialized.
    final yearService = await YearService.create();

    // Build our app within a ProviderScope, overriding the yearServiceProvider.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [yearServiceProvider.overrideWithValue(yearService)],
        child: const MyApp(), // MyApp no longer takes yearService
      ),
    );

    // Allow time for async operations like YearService.create() and initial build.
    await tester.pumpAndSettle();

    // Verify that the "Analysis" tab text is present.
    // We look for the Text widget within the Tab structure.
    expect(find.widgetWithText(Tab, 'Analysis'), findsOneWidget);

    // Verify that the "medical insights" text below "Analysis" is present.
    expect(find.text('medical insights'), findsOneWidget);

    // Optionally, verify one of the action buttons is present
    expect(find.text('Add medical records...'), findsWidgets);
  });
}
