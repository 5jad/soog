#!/usr/bin/env python3
"""
يقسّم customer_shell.dart (3076 سطر) إلى ملفات احترافية:
  - customer_shell.dart  → CustomerShell + _PageStack (التنقل فقط)
  - home_screen.dart     → HomeScreen + prodStrip + _HeroCarousel + _StoreMiniCard
  - product_card.dart    → ProdCard + BadgeWow (widgets مشتركة)
  - product_screen.dart  → pushProduct + ProductScreen (شاشة المنتج)
"""

import re

SRC = 'app/lib/features/shop/screens/customer_shell.dart'
PKG = 'package:zaboon'

# ─── header مشترك لكل ملف ─────────────────────────────────────────────────
COMMON_IMPORTS = """\
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/stores_screen.dart';
import 'package:zaboon/features/shop/screens/store_screen.dart';
import 'package:zaboon/features/shop/screens/favorites_screen.dart';
import 'package:zaboon/features/shop/screens/search_screen.dart';
import 'package:zaboon/features/auth/screens/account_screen.dart';
import 'package:zaboon/features/shop/screens/outfit_screen.dart';
import 'package:zaboon/features/shop/screens/home_screen.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
"""

with open(SRC, 'r') as f:
    lines = f.readlines()

# نجد أسطر البداية لكل قسم
def find_line(pat):
    for i, l in enumerate(lines, 1):
        if re.match(pat, l.strip()):
            return i
    return None

L_HOME     = find_line(r'class HomeScreen ')          # 171
L_PRODCARD = find_line(r'class ProdCard ')            # 820
L_BADGEWOW = find_line(r'class BadgeWow ')            # 1088
L_PUSH     = find_line(r'void pushProduct\(')         # 1116
L_PRODSCR  = find_line(r'class ProductScreen ')       # 1125
TOTAL      = len(lines)

print(f"HomeScreen   starts at: {L_HOME}")
print(f"ProdCard     starts at: {L_PRODCARD}")
print(f"BadgeWow     starts at: {L_BADGEWOW}")
print(f"pushProduct  starts at: {L_PUSH}")
print(f"ProductScreen starts at: {L_PRODSCR}")
print(f"Total lines : {TOTAL}")

def block(start, end=None):
    s = start - 1
    e = end - 1 if end else len(lines)
    return ''.join(lines[s:e])

# ── 1. customer_shell.dart ─────────────────────────────────────────────────
shell_imports = """\
import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/stores_screen.dart';
import 'package:zaboon/features/shop/screens/store_screen.dart';
import 'package:zaboon/features/shop/screens/favorites_screen.dart';
import 'package:zaboon/features/shop/screens/search_screen.dart';
import 'package:zaboon/features/auth/screens/account_screen.dart';
import 'package:zaboon/features/shop/screens/home_screen.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
"""

shell_body = block(18, L_HOME - 1)   # CustomerShell + _PageStack + pushStore
# also add pushProduct usage
with open(SRC.replace('customer_shell', 'customer_shell_NEW'), 'w') as f:
    f.write(shell_imports + '\n' + shell_body)

# ── 2. home_screen.dart ────────────────────────────────────────────────────
home_imports = """\
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/outfit_screen.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
"""
home_body = block(L_HOME, L_PRODCARD - 1)  # HomeScreen + prodStrip + _HeroCarousel + _StoreMiniCard
with open('app/lib/features/shop/screens/home_screen.dart', 'w') as f:
    f.write(home_imports + '\n' + home_body)

# ── 3. product_card.dart ──────────────────────────────────────────────────
import os
os.makedirs('app/lib/features/shop/widgets', exist_ok=True)

card_imports = """\
import 'package:flutter/material.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
"""
card_body = block(L_PRODCARD, L_PUSH - 1)  # ProdCard + BadgeWow
with open('app/lib/features/shop/widgets/product_card.dart', 'w') as f:
    f.write(card_imports + '\n' + card_body)

# ── 4. product_screen.dart ────────────────────────────────────────────────
prod_imports = """\
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/models/models.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/store_screen.dart';
import 'package:zaboon/features/shop/screens/outfit_screen.dart';
import 'package:zaboon/features/shop/widgets/product_card.dart';
"""
prod_body = block(L_PUSH, TOTAL + 1)   # pushProduct + ProductScreen + everything till EOF
with open('app/lib/features/shop/screens/product_screen.dart', 'w') as f:
    f.write(prod_imports + '\n' + prod_body)

# ── 5. استبدال customer_shell.dart الأصلي بالنسخة المقصوصة ────────────────
import shutil
shutil.move(SRC.replace('customer_shell', 'customer_shell_NEW'), SRC)

print("\n✅ Done! Files created:")
for p in [SRC,
          'app/lib/features/shop/screens/home_screen.dart',
          'app/lib/features/shop/widgets/product_card.dart',
          'app/lib/features/shop/screens/product_screen.dart']:
    import os
    lines_count = len(open(p).readlines())
    print(f"  {p}  ({lines_count} lines)")
