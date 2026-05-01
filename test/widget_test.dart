import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_mantenimiento/theme/app_theme.dart';

void main() {
  testWidgets('App shell renders with configured theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        title: 'Mantenimiento Hospitalario',
        theme: AppTheme.light,
        home: const Scaffold(
          body: Center(child: Text('app ready')),
        ),
      ),
    );

    expect(find.text('app ready'), findsOneWidget);
  });
}
