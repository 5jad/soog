import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

/// هل القيمة غلاف صورة حقيقي (رابط/بايت) وليس بانر CSS قديم؟
bool isUrlCover(String v) =>
    v.startsWith('http') ||
    v.startsWith('/uploads') ||
    v.startsWith('data:') ||
    v.startsWith('/9j');
/// صورة من base64 أو رابط أو إيموجي أول حرف
Widget storeLogo(String logo, {double size = 52, double radius = 14}) {
  if (logo.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Text('🏪', style: AppType.style(size * 0.45)),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: SizedBox(
      width: size,
      height: size,
      child: productImageBox(
        logo.startsWith('http')
            ? logo
            : logo.startsWith('/uploads')
            ? Api.base + logo
            : logo,
      ),
    ),
  );
}
Widget productImage(String? image, {double size = 80, double radius = 14}) {
  if (image != null && (image.startsWith('data:') || image.startsWith('/9j'))) {
    try {
      final bytes = base64Decode(
        image.replaceFirst(RegExp('^data:image/[a-z]+;base64,'), ''),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } catch (_) {}
  }
  // مسارات ملفات مخدومة (/uploads) أو روابط — نفس معالجة productImageBox
  if (image != null && (image.startsWith('/') || image.startsWith('http'))) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: productImageBox(image),
      ),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)],
      ),
      borderRadius: BorderRadius.circular(radius),
    ),
    alignment: Alignment.center,
    child: Text('🛍', style: AppType.style(size * 0.45)),
  );
}
/// صورة منتج تعبّئ مساحة الأب بالكامل (مربعة) — أسلوب Shein للبطاقات
/// يدعم: base64 / روابط رفع (/uploads) / إيموجي المنتجات
Widget productImageBox(String? image, {String? base, double radius = 12.0}) {
  final url = (image ?? '').trim();
  Widget ph(String emoji) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
    ),
    alignment: Alignment.center,
    child: Text(emoji, style: AppType.style(48)),
  );
  if (url.isEmpty) return ph('🛍');
  if (url.startsWith('data:') || url.startsWith('/9j')) {
    try {
      final bytes = base64Decode(
        url.replaceFirst(RegExp('^data:image/[a-z]+;base64,'), ''),
      );
      return Image.memory(bytes, fit: BoxFit.cover);
    } catch (_) {}
  }
  if (url.startsWith('http')) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ph('🛍'),
    );
  }
  if (url.startsWith('/')) {
    return Image.network(
      '${base ?? Api.base}$url',
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => ph('🛍'),
    );
  }
  return ph(url.length > 6 ? url.substring(0, 4) : url);
}
