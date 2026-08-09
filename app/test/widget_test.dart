import 'package:flutter_test/flutter_test.dart';
import 'package:zaboon/theme.dart';

void main() {
  test('تنسيق العملة', () {
    expect(money(1000), '1,000 د.ع');
    expect(money(44100), '44,100 د.ع');
    expect(money(0), '0 د.ع');
  });

  test('ترجمة الحالات', () {
    expect(statusAr('delivered'), 'تم التوصيل');
    expect(statusAr('pending'), 'قيد الانتظار');
  });
}
