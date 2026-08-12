
# 📋 دليل الانتقال من النظام القديم → Zaboon Design System v3

## 🗺 خريطة التحويل

| القديم (A / AppTokens) | الجديد (Zaboon DS) | ملاحظة |
|------------------------|-------------------|--------|
| `A.s4` / `AppTokens.space1` | `AppMetrics.xxs` | 4pt |
| `A.s8` / `AppTokens.space2` | `AppMetrics.xs` | 8pt |
| `A.s12` / `AppTokens.space3` | `AppMetrics.sm` | 12pt |
| `A.s16` / `AppTokens.space4` | `AppMetrics.md` | 16pt |
| `A.s20` | `AppMetrics.md` أو `AppMetrics.lg` | 20 غير موجودة — استخدم 16 أو 28 |
| `A.s24` / `AppTokens.space5` | `AppMetrics.lg` | 28pt (أقرب φ) |
| `A.s32` / `AppTokens.space6` | `AppMetrics.xl` | 44pt |
| `A.s40` | `AppMetrics.xl` | استخدم 44 |
| `A.s48` / `AppTokens.space8` | `AppMetrics.xxl` | 72pt |
| `A.s64` | `AppMetrics.xxl` | 72pt |
| `A.s96` | `AppMetrics.xxxl` | 116pt |
| `A.r12` / `AppTokens.radiusSm` | `AppRadius.sm` | 6pt |
| `A.r16` / `AppTokens.radiusMd` | `AppRadius.lg` | 16pt |
| `A.r20` / `AppTokens.radiusLg` | `AppRadius.xl` | 26pt |
| `A.pill` | `AppRadius.pill` | 999 |
| `A.t(14,...)` | `AppType.style(AppType.body,...)` | موحد |
| `A.t(16,...)` | `AppType.style(AppType.h3,...)` | موحد |
| `A.t(20,...)` | `AppType.style(AppType.h2,...)` | 22.5pt |
| `A.primary` | `AppColors.primary` | نفس اللون |
| `A.accent` | `AppColors.accent` | نفس اللون |
| `A.ink` | `AppColors.ink` | نفس اللون |
| `A.muted` | `AppColors.muted` | نفس اللون |
| `A.line` | `AppColors.line` | نفس اللون |
| `A.card()` | `AppDecor.card()` | محسّن |
| `A.glass()` | `AppDecor.card()` | تم إلغاء الزجاج على البطاقات |
| `A.gradNavy` | `AppColors.gradNavy` | نفس التدرج |
| `LiquidGlass.blurLayer1` | `AppGlass.blurLight` | 10 |
| `LiquidGlass.blurLayer2` | `AppGlass.blurMedium` | 20 |
| `LiquidGlass.blurLayer3` | `AppGlass.blurHeavy` | 30 |

## ⚡ أمثلة عملية للتحويل

### قبل (النظام القديم):
```dart
Container(
  padding: const EdgeInsets.all(A.s16),
  decoration: A.card(radius: A.r16),
  child: Text('مرحباً', style: A.t(16, w: FontWeight.w700)),
);
```

### بعد (Zaboon DS):
```dart
Container(
  padding: const EdgeInsets.all(AppMetrics.md),
  decoration: AppDecor.card(radius: AppRadius.lg),
  child: Text('مرحباً', style: AppType.h3Style),
);
```

## 🎯 القواعد الذهبية الجديدة

1. **لا تستخدم أرقامًا مباشرة** — كل قياس يأتي من `AppMetrics` أو `AppRadius`
2. **التايبوغرافي** — استخدم `AppType.style()` أو الـ getters الجاهزة
3. **الألوان** — `AppColors.*` فقط، لا `Color(0xFF...)` مباشرة
4. **الظلال** — `AppShadows.sm/md/lg/xl` بدل كتابة BoxShadow يدوياً
5. **المدد** — `AppDurations.fast/normal/slow` للحركات
6. **الاهتزازات** — `AppHaptics.light()` للتفاعلات

## 📐 لماذا النسبة الذهبية؟

| القيمة | φ × السابقة | الاستخدام |
|--------|-------------|-----------|
| 4 | Base | أصغر مسافة |
| 8 | 4×2 | مسافة صغيرة |
| 12 | ~8×φ | مسافة متوسطة |
| 16 | ~12×φ | مسافة قياسية |
| 28 | ~16×φ | مسافة كبيرة |
| 44 | ~28×φ | مسافة ضخمة |
| 72 | ~44×φ | أقسام كاملة |

هذا يعطي إيقاعًا بصريًا طبيعيًا — العين البشرية تُفضّل النسبة الذهبية!
