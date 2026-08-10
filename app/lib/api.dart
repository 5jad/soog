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
    // روابط الشبكة المنزلية القديمة (192.168..) ما تصلح بعد الرفع السحابي — نتجاهلها نهائياً
    if (saved != null && (saved.contains('192.168') || saved.contains('localhost'))) saved = null;
    if (saved != null && saved.isNotEmpty) base = saved;
    // لو الرابط الحالي معطّل → نرجع للسحابة فوراً (ولا نخزن أي رابط محلي)
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

  static Future<dynamic> get(String path) async {
    debugPrint('[API] GET $path → $base$path');
    try {
      final r = await http.get(Uri.parse('$base$path'), headers: _headers());
      debugPrint('[API] ← ${r.statusCode} $path');
      return _handle(r);
    } catch (e) {
      debugPrint('[API] ❌ $path :: $e');
      rethrow;
    }
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(Uri.parse('$base$path'),
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(r);
  }

  static Future<dynamic> patch(String path, [Map<String, dynamic>? body]) async {
    final r = await http.patch(Uri.parse('$base$path'),
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(r);
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final r = await http.put(Uri.parse('$base$path'),
        headers: _headers(), body: body == null ? null : jsonEncode(body));
    return _handle(r);
  }

  static Future<dynamic> del(String path) async {
    final r = await http.delete(Uri.parse('$base$path'), headers: _headers());
    return _handle(r);
  }

  static dynamic _handle(http.Response r) {
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {}
    if (r.statusCode >= 400) {
      final msg = body is Map ? (body['error'] ?? 'خطأ غير متوقع') : 'تعذر الاتصال بالخادم';
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
    final d = await post('/api/uploads/upload', {'files': files});
    return ((d?['urls'] ?? []) as List).cast<String>();
  }

  /// رفع صور جاهزة (بايتات) — تستخدم بعد القصّ
  static Future<List<String>> uploadBytes(List<Uint8List> images) async {
    final files = images.take(8).map((b) => 'data:image/jpeg;base64,${base64Encode(b)}').toList();
    if (files.isEmpty) return [];
    final d = await post('/api/uploads/upload', {'files': files});
    return ((d?['urls'] ?? []) as List).cast<String>();
  }
}

class ApiException implements Exception {
  final String message;
  final int code;
  ApiException(this.message, this.code);
  @override
  String toString() => message;
}

/// حالة التطبيق المشتركة (زر/عربة/تبويبات)
class AppState extends ChangeNotifier {
  static final AppState i = AppState._();
  AppState._();

  final ValueNotifier<int> unreadNotifs = ValueNotifier(0); // عدّاد الإشعارات غير المقروءة
  final ValueNotifier<int> favsCount = ValueNotifier(0); // عدّاد المفضلة — شارة تبويب المفضلة
  final ValueNotifier<int> storesCount = ValueNotifier(0); // عدد المتاجر المتاحة (الشريط العلوي) — يحدّث كل الصفحات
  List<Map<String, dynamic>> guestCart = []; // السلة المحلية للضيوف
  final ValueNotifier<int> cartCount = ValueNotifier(0); // عداد السلة — يحرك الشارات والزر العائم
  final ValueNotifier<int> favsReload = ValueNotifier(0); // إشارة لتحديث تبويب المفضلة
  static const _cartKey = 'zaboon_cart_count';

  /// تحديث العداد وحفظه — الرقم يبقى حتى بعد إغلاق التطبيق
  void setCart(int n) {
    cartCount.value = n < 0 ? 0 : n;
    SharedPreferences.getInstance().then((p) => p.setInt(_cartKey, cartCount.value));
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
