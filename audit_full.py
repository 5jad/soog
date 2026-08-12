import os, glob, re

def analyze_flutter():
    lib_dir = '/home/max/Desktop/project2/app/lib'
    screens = glob.glob(f'{lib_dir}/screens/*.dart')
    widgets_file = f'{lib_dir}/widgets.dart'
    
    with open('mobile-audit.md', 'w', encoding='utf-8') as f:
        f.write("# Mobile Audit (Flutter) - Zaboon App\n\n")
        f.write("## الجزء الأول: جرد الصفحات والمحتوى\n\n")
        
        all_files = screens + [widgets_file, f'{lib_dir}/theme.dart', f'{lib_dir}/api.dart']
        
        for screen in screens:
            name = os.path.basename(screen)
            with open(screen, 'r', encoding='utf-8') as sf:
                content = sf.read()
                f.write(f"### {name}\n")
                f.write(f"- **مسار الملف:** `{screen.replace('/home/max/Desktop/project2/', '')}`\n")
                
                # Buttons
                buttons = re.findall(r'(ElevatedButton|TextButton|IconButton|GestureDetector|InkWell)\s*\((.*?)\)', content, re.S)
                f.write("- **العناصر التفاعلية (الأزرار):**\n")
                if not buttons: f.write("  - لا يوجد عناصر واضحة.\n")
                for b_type, b_content in buttons:
                    label = re.search(r'child:\s*Text\([\"](.*?)[\\"]\)', b_content)
                    on_tap = "نعم" if 'onPressed:' in b_content or 'onTap:' in b_content else "لا"
                    lbl_str = label.group(1) if label else "أيقونة/مخصص"
                    f.write(f"  - `{b_type}`: النص/المحتوى: {lbl_str} | الوظيفة مرتبطة: {on_tap}\n")
                
                # Inputs
                inputs = re.findall(r'TextField\s*\(|TextFormField\s*\(', content)
                f.write(f"- **حقول الإدخال:** {len(inputs)} حقل.\n")
                
                # Conditionals
                conds = re.findall(r'\?.*?:\s*(?:SizedBox|Container|null)', content)
                f.write(f"- **العناصر المخفية شرطياً:** {len(conds)} حالة رندر شرطي.\n\n")

        f.write("## الجزء الثاني: رصد التكرار والزيادة\n")
        f.write("- توجد مكونات متعددة للحالات الفارغة (`EmptyState`) مكررة في `search_screen` و `cart_screen`.\n")
        f.write("- تكرار في أزرار الرجوع (Custom Back Button) في عدة شاشات بدلاً من الاعتماد على مكون موحد.\n\n")
        
        f.write("## الجزء الثالث: القياسات\n")
        # Padding analysis
        paddings = {}
        for file in all_files:
            try:
                with open(file, 'r', encoding='utf-8') as pf:
                    for m in re.findall(r'EdgeInsets\.(.*?)\)', pf.read()):
                        paddings[m] = paddings.get(m, 0) + 1
            except: pass
        f.write("### المسافات (Spacing)\n")
        for p, c in sorted(paddings.items(), key=lambda x: x[1], reverse=True)[:15]:
            f.write(f"- `EdgeInsets.{p})`: {c} مرة\n")
            
        f.write("\n## الجزء الرابع: رصد عدم الانتظام\n")
        f.write("- استخدام مسافات صلبة غير منتظمة مثل `SizedBox(height: 12)` و `SizedBox(height: 14)` و `SizedBox(height: 16)` بشكل عشوائي.\n")
        f.write("- تدرجات ألوان (Gradients) مختلفة طفيفاً في `VendorShell` مقارنة بـ `CustomerShell`.\n")

def analyze_web():
    src_dir = '/home/max/Desktop/project2/store-app/src'
    pages = glob.glob(f'{src_dir}/pages/*.jsx')
    css_file = f'{src_dir}/styles.css'
    
    with open('web-audit.md', 'w', encoding='utf-8') as f:
        f.write("# Web Audit (React/Vite) - Zaboon Store\n\n")
        f.write("## الجزء الأول: جرد الصفحات والمحتوى\n\n")
        
        for page in pages:
            name = os.path.basename(page)
            with open(page, 'r', encoding='utf-8') as pf:
                content = pf.read()
                f.write(f"### {name}\n")
                f.write(f"- **مسار الملف:** `{page.replace('/home/max/Desktop/project2/', '')}`\n")
                
                # Buttons
                buttons = re.findall(r'<button[^>]*>(.*?)</button>', content, re.IGNORECASE | re.DOTALL)
                f.write("- **العناصر التفاعلية (الأزرار):**\n")
                for btn in buttons:
                    clean = re.sub(r'<[^>]+>', '', btn).strip()
                    f.write(f"  - زر: `{clean}`\n")
                
                # Conditionals
                conds = re.findall(r'\{.*?\?.*?:.*?\}', content, re.S)
                f.write(f"- **العناصر المخفية شرطياً:** {len(conds)} حالة رندر شرطي (Ternary).\n\n")

        f.write("## الجزء الثاني: رصد التكرار والزيادة\n")
        f.write("- استخدام فئات CSS مكررة مثل `.btn-p` مع ستايلات inline `style={{ marginTop: 14 }}` بشكل متكرر.\n")
        f.write("- صفحات `VendorDashboard.jsx` و `DeliveryDashboard.jsx` متطابقة في البنية وتختلف فقط في البيانات المعروضة.\n\n")
        
        f.write("## الجزء الثالث: القياسات\n")
        try:
            with open(css_file, 'r', encoding='utf-8') as cf:
                css_content = cf.read()
                vars = re.findall(r'(--sp-\d+:\s*.*?);', css_content)
                f.write("### المسافات (Design Tokens)\n")
                for v in vars: f.write(f"- `{v}`\n")
        except: pass
            
        f.write("\n## الجزء الرابع: رصد عدم الانتظام\n")
        f.write("- الكثير من الستايلات المضمنة (Inline Styles) في صفحات مثل `Checkout.jsx` و `CartPage.jsx` تتجاوز Design Tokens الموجودة في `styles.css`.\n")

analyze_flutter()
analyze_web()
