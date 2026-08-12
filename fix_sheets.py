import re

files = ['app/lib/screens/search_screen.dart', 'app/lib/screens/stores_screen.dart']

old_str = """      builder: (ctx) => GlassSheet(
        child: StatefulBuilder("""

new_str = """      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder("""

for path in files:
    with open(path, 'r') as f:
        content = f.read()
    
    content = content.replace(old_str, new_str)
    
    with open(path, 'w') as f:
        f.write(content)

