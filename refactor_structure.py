import os
import shutil
import re

base_dir = "app/lib"

file_map = {
    "main.dart": "main.dart",
    "api.dart": "core/api/api.dart",
    "models.dart": "core/models/models.dart",
    "widgets.dart": "core/widgets/widgets.dart",
    "lottie_box.dart": "core/widgets/lottie_box.dart",
    "zaboon_design_system.dart": "core/theme/zaboon_design_system.dart",
    "theme.dart": "core/theme/theme.dart",
    "theme/app_tokens.dart": "core/theme/app_tokens.dart",
    
    "screens/login_screen.dart": "features/auth/screens/login_screen.dart",
    "screens/account_screen.dart": "features/auth/screens/account_screen.dart",
    
    "screens/customer_shell.dart": "features/shop/screens/customer_shell.dart",
    "screens/category_products_screen.dart": "features/shop/screens/category_products_screen.dart",
    "screens/store_screen.dart": "features/shop/screens/store_screen.dart",
    "screens/stores_screen.dart": "features/shop/screens/stores_screen.dart",
    "screens/search_screen.dart": "features/shop/screens/search_screen.dart",
    "screens/favorites_screen.dart": "features/shop/screens/favorites_screen.dart",
    "screens/outfit_screen.dart": "features/shop/screens/outfit_screen.dart",
    "map_screen.dart": "features/shop/screens/map_screen.dart",
    
    "screens/cart_screen.dart": "features/cart_checkout/screens/cart_screen.dart",
    "screens/order_success_screen.dart": "features/cart_checkout/screens/order_success_screen.dart",
    
    "screens/orders_screen.dart": "features/orders/screens/orders_screen.dart",
    
    "screens/vendor_shell.dart": "features/vendor/screens/vendor_shell.dart",
    
    "screens/delivery_shell.dart": "features/delivery/screens/delivery_shell.dart",
    
    "screens/admin_shell.dart": "features/admin/screens/admin_shell.dart",
    
    "screens/chat_screen.dart": "features/chat/screens/chat_screen.dart",
    "screens/notifications_screen.dart": "features/notifications/screens/notifications_screen.dart",
    "screens/points_screen.dart": "features/points/screens/points_screen.dart",
    
    "screens/shell.dart": "core/routing/shell.dart"
}

# 1. Create directories and move files
print("Creating directories and moving files...")
for old_path, new_path in file_map.items():
    if old_path == new_path:
        continue
    
    src = os.path.join(base_dir, old_path)
    dst = os.path.join(base_dir, new_path)
    
    if os.path.exists(src):
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        print(f"Moved: {src} -> {dst}")

# Remove old empty directories
try:
    if os.path.exists(os.path.join(base_dir, "screens")):
        shutil.rmtree(os.path.join(base_dir, "screens"))
    if os.path.exists(os.path.join(base_dir, "theme")):
        shutil.rmtree(os.path.join(base_dir, "theme"))
except:
    pass

# 2. Build reverse lookup dictionary for filename -> package path
# We only care about the basename of the file for the lookup since filenames are mostly unique.
# E.g. 'login_screen.dart' -> 'package:zaboon/features/auth/screens/login_screen.dart'
# If someone imports '../screens/login_screen.dart', we just extract 'login_screen.dart' and replace.
lookup = {}
for new_path in file_map.values():
    basename = os.path.basename(new_path)
    lookup[basename] = f"package:zaboon/{new_path}"

# Special cases or duplicates? (e.g. app_tokens.dart, theme.dart)
# Let's iterate over all dart files in lib/ and fix their imports
print("Fixing imports...")
import_pattern = re.compile(r'''import\s+['"]([^'"]+\.dart)['"]\s*;''')

def fix_imports(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    def replacer(match):
        original_import = match.group(1)
        # Skip package: or dart: imports
        if original_import.startswith('package:') or original_import.startswith('dart:'):
            return match.group(0)
        
        imported_basename = os.path.basename(original_import)
        
        if imported_basename in lookup:
            new_import = lookup[imported_basename]
            return f"import '{new_import}';"
        
        return match.group(0)
    
    new_content = import_pattern.sub(replacer, content)
    
    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated imports in {file_path}")

for root, _, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.dart'):
            fix_imports(os.path.join(root, file))

print("Done!")
