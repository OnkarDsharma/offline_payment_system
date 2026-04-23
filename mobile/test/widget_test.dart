import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:offline_wallet/app.dart';

void main() {
  testWidgets('Bootstraps app shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OfflineWalletApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
