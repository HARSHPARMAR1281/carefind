import 'package:carefind/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CareFind app loads splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const CareFindApp());
    expect(find.text('CareFind'), findsOneWidget);
    expect(find.byIcon(Icons.local_hospital), findsOneWidget);
  });
}
