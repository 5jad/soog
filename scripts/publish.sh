#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
# زبون — نشر نسخة جديدة (المصدر الوحيد للنسخ)
#
# الاستخدام:  ./scripts/publish.sh 1.1.0  "وصف التغييرات"
#
# 1) يرفع الإصدار في الكود + ملف الإصدار على السيرفر
# 2) يبني APK release
# 3) ينسخ APK لمجلد الموقع (يرفع كل الزبائن منه دائماً)
# 4) يعرض لك أمر git للرفع → Vercel يتحدث تلقائياً
# ═══════════════════════════════════════════════════════════
set -e
cd "$(dirname "$0")/.."

VERSION="${1:?أعطني رقم الإصدار — مثال: ./scripts/publish.sh 1.1.0 \"رسالة\"}"
BUILD=$(( $(cat backend/src/app-version.json | python3 -c "import sys,json;print(json.load(sys.stdin)['build'])") + 1 ))
CHANGELOG="${2:-تحديث جديد}"

echo "📦 نشر الإصدار $VERSION (build $BUILD): $CHANGELOG"

# 1) الإصدار في الكود
sed -i "s/const String kAppVersion = '[^']*';/const String kAppVersion = '$VERSION';/" app/lib/core/widgets/states.dart
sed -i "s/const int kAppBuild = [0-9]*;/const int kAppBuild = $BUILD;/" app/lib/core/widgets/states.dart

# 2) ملف الإصدار على السيرفر (ينتشر مع الـ API للزبائن)
python3 - "$VERSION" "$BUILD" "$CHANGELOG" << 'EOF'
import json, sys, datetime
v, b, c = sys.argv[1], int(sys.argv[2]), sys.argv[3]
path = 'backend/src/app-version.json'
d = json.load(open(path, encoding='utf-8'))
d.update({'version': v, 'build': b, 'changelog': c, 'updated_at': datetime.date.today().isoformat()})
json.dump(d, open(path, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
print('✓ app-version.json:', json.dumps(d, ensure_ascii=False))
EOF

# 3) بناء الـ APK
echo "🔨 بناء APK release (ياخذ دقيقة)..."
(cd app && flutter build apk --release 2>&1 | tail -2)

# 4) نسخه للموقع — الزبائن يحملون دائماً من الموقع
mkdir -p landing/downloads backend/public/landing/downloads
cp app/build/app/outputs/flutter-apk/app-release.apk landing/downloads/zaboon-app.apk
cp app/build/app/outputs/flutter-apk/app-release.apk backend/public/landing/downloads/zaboon-app.apk
echo "✓ APK: $(ls -lh landing/downloads/zaboon-app.apk | awk '{print $5}')"

# 5) خطوة الزبون الأخيرة
echo ""
echo "══════════ انتهى — ارفع للنت (يحدث الموقع تلقائياً) ══════════"
echo "  cd project2 && git add -A && git commit -m \"إصدار $VERSION: $CHANGELOG\" && git push"
echo "══════════════════════════════════════════════════════════════"