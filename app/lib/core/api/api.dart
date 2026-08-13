import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// عميل الـ API — كله يمر من هنا (base URL سهل التغيير)
class Api {
  // السحابة — يشتغل من أي مكان وبلا حاسوب منزلي
  static const String cloud = 'https://soog-delta.vercel.app';
  static String base = cloud;

  static String? _token;
  static Map<String, dynamic>? me;

  static bool get logged => _token != null;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    var saved = p.getString('zaboon_base');
    // نجرّب الرابط المحفوظ أولاً (سحابة أو محلي/نفق) — لو معطّل نرجع للسحابة
    if (saved != null && saved.isNotEmpty) base = saved;
    if (!await _reachable(base)) {
      base = cloud;
      await p.setString('zaboon_base', base);
    }
    _token = p.getString('zaboon_token');
    if (_token != null) {
      try {
        final d = await get('/api/auth/me');
        me = d is Map ? (d['user'] ?? d) : null;
      } catch (_) {
        // التوكن منتهي/خاطئ → نسحبه ونرجع كضيف
        await clear();
      }
    }
  }

  static Future<bool> _reachable(String url) async {
    try {
      final r = await http
          .get(Uri.parse('$url/api/health'))
          .timeout(const Duration(seconds: 4));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBase(String url) async {
    var u = url.trim();
    if (u.isEmpty) return;
    if (!u.startsWith('http')) u = 'http://$u';
    u = u.replaceAll(RegExp(r'/+$'), '');
    base = u;
    final p = await SharedPreferences.getInstance();
    await p.setString('zaboon_base', u);
  }

  static Future<void> saveToken(String t) async {
    _token = t;
    final p = await SharedPreferences.getInstance();
    await p.setString('zaboon_token', t);
  }

  static Future<void> clear() async {
    _token = null;
    me = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('zaboon_token');
  }

  static Map<String, String> _headers({bool auth = true}) => {
    'Content-Type': 'application/json',
    'Bypass-Tunnel-Reminder': 'true',
    if (auth && _token != null) 'Authorization': 'Bearer $_token',
  };

  // مهلة لكل طلب — الشبكة الضعيفة ما تعلّق الشاشة على دوران للأبد
  static const Duration _t = Duration(seconds: 12);

  static Future<dynamic> get(String path) async {
    debugPrint('[API] GET $path → $base$path');
    try {
      final r = await http
          .get(Uri.parse('$base$path'), headers: _headers())
          .timeout(_t);
      debugPrint('[API] ← ${r.statusCode} $path');
      return _handle(r);
    } catch (e) {
      debugPrint('[API] ❌ $path :: $e');
      if (e is ApiException) rethrow;
      throw ApiException('تعذر الاتصال بالخادم — تحقق من شبكة الإنترنت', 0);
    }
  }

  static Future<dynamic> post(
    String path, [
    Map<String, dynamic>? body,
    Duration timeout = _t,
  ]) async {
    final r = await http
        .post(
          Uri.parse('$base$path'),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(timeout);
    return _handle(r);
  }

  static Future<dynamic> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final r = await http
        .patch(
          Uri.parse('$base$path'),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_t);
    return _handle(r);
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final r = await http
        .put(
          Uri.parse('$base$path'),
          headers: _headers(),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_t);
    return _handle(r);
  }

  static Future<dynamic> del(String path) async {
    final r = await http
        .delete(Uri.parse('$base$path'), headers: _headers())
        .timeout(_t);
    return _handle(r);
  }

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 400) {
      final msg = body is Map
          ? (body['error'] ?? 'خطأ غير متوقع')
          : 'تعذر الاتصال بالخادم';
      throw ApiException(msg, r.statusCode);
    }
    return body;
  }

  /// رفع صور من معرض الجهاز (base64 → السيرفر يحفظها ويُرجّع روابطها)
  static Future<List<String>> uploadImages(List<String> paths) async {
    final files = <String>[];
    for (final p in paths.take(8)) {
      try {
        final bytes = await File(p).readAsBytes();
        files.add('data:image/jpeg;base64,${base64Encode(bytes)}');
      } catch (_) {}
    }
    if (files.isEmpty) return [];
    final d = await post(
      '/api/uploads/upload',
      {'files': files},
      const Duration(seconds: 120),
    );
    return ((d?['urls'] ?? []) as List).cast<String>();
  }

  /// رفع صور جاهزة (بايتات) — تستخدم بعد القصّ
  static Future<List<String>> uploadBytes(List<Uint8List> images) async {
    final files = images
        .take(8)
        .map((b) => 'data:image/jpeg;base64,${base64Encode(b)}')
        .toList();
    if (files.isEmpty) return [];
    final d = await post(
      '/api/uploads/upload',
      {'files': files},
      const Duration(seconds: 120),
    );
    return ((d?['urls'] ?? []) as List).cast<String>();
  }

  /// بدء جلسة تحقق الهاتف عبر تلغرام — الرقم من التوكن، لا من البادي
  static Future<Map<String, dynamic>> verifyStart() async {
    final d = await post('/api/telegram/verify-start', {});
    return (d ?? {}) as Map<String, dynamic>;
  }

  /// حالة جلسة التحقق — يستدعيها الـ polling كل 2.5 ثانية
  static Future<String> verifyStatus(String token) async {
    final d = await get('/api/telegram/verify-status?token=$token');
    return (d is Map ? d['status']?.toString() : 'expired') ?? 'expired';
  }

  /// بدء التسجيل: رقم مكتوب → جلسة تحقق؛ الرقم المسجل مسبقاً يوجّه للدخول بلا OTP
  static Future<Map<String, dynamic>> registerStart(String phone) async {
    final d = await post('/api/auth/register-start', {'phone': phone});
    return (d ?? {}) as Map<String, dynamic>;
  }

  /// حالة جلسة التسجيل — عامة (لا حساب بعد)؛ حمايتها بالتوكن العشوائي نفسه
  static Future<String> registerStatus(String token) async {
    final d = await get('/api/telegram/register-status?token=$token');
    return (d is Map ? d['status']?.toString() : 'expired') ?? 'expired';
  }

  /// التثبت من رمز البوت بعد مطابقة الرقم
  static Future<void> registerCode(String token, String code) async {
    await post('/api/auth/register-code', {'token': token, 'code': code});
  }

  /// إتمام التسجيل: رمز مؤكد + الاسم وكلمة المرور → توك + حساب مفعّل
  static Future<Map<String, dynamic>> registerConfirm({
    required String token,
    required String name,
    required String password,
    String referral = '',
  }) async {
    final d = await post('/api/auth/register-confirm', {
      'token': token,
      'name': name,
      'password': password,
      if (referral.trim().isNotEmpty) 'referral': referral.trim(),
    });
    return (d ?? {}) as Map<String, dynamic>;
  }
}

class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, this.code);
  @override
  String toString() => message;
}

/// مجموع القطع في السلة (وليس عدد أصناف السلة) — يغذّي شارة السلة
int cartTotalQty(List items) => items.fold(0, (a, b) {
      final qty = (b as Map)['qty'];
      return a + ((qty is num) ? qty.toInt() : 1);
    });

/// حالة التطبيق المشتركة (زر/عربة/تبويبات)
class AppState extends ChangeNotifier {
  static final AppState i = AppState._();
  AppState._();

  final ValueNotifier<int> unreadNotifs = ValueNotifier(
    0,
  ); // عدّاد الإشعارات غير المقروءة
  final ValueNotifier<int> notifReload = ValueNotifier(
    0,
  ); // إشارة لتحديث شاشة الإشعارات عند وصول جديد
  final ValueNotifier<int> favsCount = ValueNotifier(
    0,
  ); // عدّاد المفضلة — شارة تبويب المفضلة
  final ValueNotifier<int> storesCount = ValueNotifier(
    0,
  ); // عدد المتاجر المتاحة (الشريط العلوي) — يحدّث كل الصفحات
  List<Map<String, dynamic>> guestCart = []; // السلة المحلية للضيوف
  final ValueNotifier<int> cartCount = ValueNotifier(
    0,
  ); // عداد السلة — يحرك الشارات والزر العائم
  final ValueNotifier<int> favsReload = ValueNotifier(
    0,
  ); // إشارة لتحديث تبويب المفضلة
  static const _cartKey = 'zaboon_cart_count';

  /// تحديث العداد وحفظه — الرقم يبقى حتى بعد إغلاق التطبيق
  void setCart(int n) {
    cartCount.value = n < 0 ? 0 : n;
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_cartKey, cartCount.value),
    );
  }

  /// استرجاع الرقم المحفوظ عند فتح التطبيق
  Future<void> loadCart() async {
    final p = await SharedPreferences.getInstance();
    cartCount.value = p.getInt(_cartKey) ?? 0;
  }

  /// تحديث عدد المتاجر للشريط العلوي — يُجلب مرة عند الإقلاع ويُحدَّث من الرئيسية أيضاً
  Future<void> refreshStores() async {
    try {
      final d = await Api.get('/api/stores');
      storesCount.value = (d['stores'] ?? []).length;
    } catch (_) {}
  }

  void refresh() => notifyListeners();
}

/// فئة مضغوطة لأرقام الدنانير (بدون فواصل مكتوبة يدوياً)
String intlNum(dynamic v) {
  if (v == null) return '';
  return v.toString();
}
