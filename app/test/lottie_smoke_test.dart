import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zaboon/lottie_box.dart';

void main() {
  const keys = [
    'loading',
    'success',
    'cart_empty',
    'fav_empty',
    'orders_empty',
    'no_results',
    'cart_ok',
  ];
  for (final key in keys) {
    testWidgets('LottieBox renders $key', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LottieBox(
          assetKey: key,
          fallback: const SizedBox.shrink(),
          loop: key == 'loading',
        ),
      ));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      expect(find.byType(LottieBox), findsOneWidget);
    });
  }
}
