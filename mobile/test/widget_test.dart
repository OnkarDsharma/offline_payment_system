import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offline_wallet/app.dart';

void main() {
  testWidgets('Bootstraps and shows prototype home', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: OfflineWalletApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Offline Wallet Prototype'), findsOneWidget);
    expect(find.text('Receive'), findsOneWidget);
  });
}
