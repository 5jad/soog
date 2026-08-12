import re

with open('app/lib/screens/customer_shell.dart', 'r') as f:
    content = f.read()

# I need to import dart:ui
if "import 'dart:ui';" not in content:
    content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'dart:ui';")

content = content.replace("filter: AppGlass.blurHeavy,", "filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),")

with open('app/lib/screens/customer_shell.dart', 'w') as f:
    f.write(content)
