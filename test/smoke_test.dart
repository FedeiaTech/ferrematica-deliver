import 'package:ferrematica_express/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('app boots to the splash screen without crashing', (
    tester,
  ) async {
    await pumpApp(tester, const FerrematicaApp());
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('go_router navigates to the placeholder route', (tester) async {
    await pumpApp(tester, const FerrematicaApp());
    await tester.pump();

    final context = tester.element(find.byType(CircularProgressIndicator));
    GoRouter.of(context).go('/placeholder');
    await tester.pumpAndSettle();

    expect(find.text('Ferrematica Express'), findsOneWidget);
    expect(find.text('Scaffold ready — no feature yet.'), findsOneWidget);
  });
}
