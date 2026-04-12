// Copyright (c) 2026 Y.Rakmani. All rights reserved.

import 'package:flutter_test/flutter_test.dart';

import 'package:beacon_simulator/main.dart';

void main() {
  testWidgets('App loads and shows Start', (WidgetTester tester) async {
    await tester.pumpWidget(const BeaconSimulatorApp());
    expect(find.textContaining('beacon'), findsWidgets);
    expect(find.text('Start'), findsOneWidget);
  });
}
