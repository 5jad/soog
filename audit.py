import os
import re
import glob

def process_flutter():
    pages = glob.glob('/home/max/Desktop/project2/app/lib/screens/*.dart')
    components = glob.glob('/home/max/Desktop/project2/app/lib/*.dart')
    # This is a simplified extraction script just to get us started
    
    with open('mobile-audit.md', 'w') as f:
        f.write("# Mobile Audit (Flutter)\n\n")
        f.write("## Part 1: Pages & Content\n\n")
        for page in pages:
            name = os.path.basename(page)
            f.write(f"### {name}\n")
            with open(page, 'r') as pf:
                content = pf.read()
                buttons = re.findall(r'(?:ElevatedButton|TextButton|IconButton|GestureDetector|InkWell)[\s\S]*?(?:child:\s*Text\(\'(.*?)\'\)|icon:\s*Icon\((.*?)\))', content)
                f.write(f"- Buttons/Interactions: {len(buttons)}\n")
        
        f.write("\n## Part 3: Measurements\n")
        # Find paddings, margins
        paddings = {}
        for file in pages + components:
            with open(file, 'r') as pf:
                matches = re.findall(r'EdgeInsets\.(?:all|symmetric|only)\((.*?)\)', pf.read())
                for m in matches:
                    paddings[m] = paddings.get(m, 0) + 1
        for p, c in sorted(paddings.items(), key=lambda x: x[1], reverse=True)[:20]:
            f.write(f"- `{p}`: {c} times\n")

def process_web():
    pages = glob.glob('/home/max/Desktop/project2/store-app/src/pages/*.jsx')
    with open('web-audit.md', 'w') as f:
        f.write("# Web Audit (React)\n\n")
        f.write("## Part 1: Pages & Content\n\n")
        for page in pages:
            name = os.path.basename(page)
            f.write(f"### {name}\n")
            with open(page, 'r') as pf:
                content = pf.read()
                buttons = re.findall(r'<button[^>]*>(.*?)</button>', content, re.IGNORECASE | re.DOTALL)
                f.write(f"- Buttons: {len(buttons)}\n")

process_flutter()
process_web()
