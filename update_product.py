import re

with open('app/lib/screens/customer_shell.dart', 'r') as f:
    content = f.read()

# Add extendBody: true to the Scaffold if not there (it's a Scaffold somewhere returning this body)
# Wait, let's just make the bottomNavigationBar a Glassmorphism bar

bottom_nav_old = """      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0x140A1120), width: 1)),
        ),
        child: Row(children: ["""

bottom_nav_new = """      extendBody: true,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          border: const Border(top: BorderSide(color: Color(0x140A1120), width: 1)),
        ),
        child: ClipRRect(
          child: BackdropFilter(
            filter: AppGlass.blurHeavy,
            child: Row(children: ["""

content = content.replace(bottom_nav_old, bottom_nav_new)

# Fix missing closing tags because we added ClipRRect and BackdropFilter
bottom_nav_end_old = """              },
            )),
          ),
        ]),
      ),
    );
  }"""
bottom_nav_end_new = """              },
            )),
          ),
        ]))),
      ),
    );
  }"""

content = content.replace(bottom_nav_end_old, bottom_nav_end_new)


# Trust Banner modification
trust_old = """                  // ═══ خدمات التوصيل والدفع — شريط أفقي ═══
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),"""

trust_new = """                  // ═══ لماذا تشتري من هنا؟ (Trust Banner) ═══
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),"""

content = content.replace(trust_old, trust_new)

# Change 'أضف للسلة' to 'إضافة للسلة'
content = content.replace("'أضف للسلة · ${formatMoney(prod.displayPrice * qty)}'", "'إضافة للسلة · ${formatMoney(prod.displayPrice * qty)}'")

with open('app/lib/screens/customer_shell.dart', 'w') as f:
    f.write(content)

