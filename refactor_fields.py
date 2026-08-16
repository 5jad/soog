import re

with open('app/lib/features/auth/screens/login_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# We need to replace _registerFields entirely.
new_register_fields = """
  List<Widget> _registerFields() {
    return [
      // ═══ اختيار نوع الحساب: زبون / تاجر ═══
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          _regRoleBtn('customer', 'زبون 🛍️'),
          _regRoleBtn('vendor', 'تاجر 🏪'),
        ]),
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('name'),
        controller: name,
        hint: 'الاسم الكامل',
        icon: Icons.person_outline,
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('phone'),
        controller: phone,
        hint: 'رقم الهاتف (مثال: 07800000000)',
        icon: Icons.phone_android_rounded,
        isPhone: true,
      ),
      const SizedBox(height: 12),
      _Field(
        key: const ValueKey('password'),
        controller: password,
        hint: 'كلمة المرور (6 أحرف أو أكثر)',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        obscure: obscurePass,
        onToggleObscure: () => setState(() => obscurePass = !obscurePass),
      ),
      if (regRole == 'vendor') ...[
        const SizedBox(height: 12),
        const Divider(color: AppColors.line),
        const SizedBox(height: 12),
        Text('بيانات المتجر', style: AppType.style(14, weight: FontWeight.w900, color: AppColors.primary)),
        const SizedBox(height: 12),
        _Field(
          key: const ValueKey('storeName'),
          controller: storeName,
          hint: 'اسم المتجر',
          icon: Icons.storefront_outlined,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: selCat,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'القسم',
            hintText: 'اختر قسم المتجر',
            filled: true,
            fillColor: AppColors.bg,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppColors.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppColors.line),
            ),
          ),
          items: allCats.isEmpty
              ? [const DropdownMenuItem<int?>(value: null, child: Text('...جاري التحميل'))]
              : [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('اختر القسم'),
                  ),
                  ...allCats.map(
                    (c) => DropdownMenuItem<int?>(
                      value: (c['id'] as num).toInt(),
                      child: Text('${c['icon'] ?? ''} ${c['name']}'),
                    ),
                  ),
                ],
          onChanged: (v) => setState(() => selCat = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'صورة البطاقة الوطنية 🪪',
                style: AppType.style(13, color: AppColors.ink, weight: FontWeight.w800),
              ),
            ),
            if (storeIdCard != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('تم الرفع ✓',
                    style: AppType.style(11, color: AppColors.success, weight: FontWeight.w700)),
              ),
              IconButton(
                onPressed: () => setState(() => storeIdCard = null),
                icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
                visualDensity: VisualDensity.compact,
                tooltip: 'إزالة',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                productImageBox(storeIdCard, base: Api.base),
                if (storeIdCard == null)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFF1F0EC), Color(0xFFE8E6E0)]),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.badge_outlined, size: 30, color: AppColors.muted),
                        const SizedBox(height: 6),
                        Text('لم تُرفع بعد',
                            style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndUpload(
                  ImageSource.camera,
                  'التقاط البطاقة 📷',
                  1.586,
                  (u) => setState(() => storeIdCard = u),
                ),
                icon: const Icon(Icons.photo_camera_outlined, size: 17),
                label: const Text('كاميرا'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickAndUpload(
                  ImageSource.gallery,
                  'اختيار من المعرض 🖼',
                  1.586,
                  (u) => setState(() => storeIdCard = u),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 17),
                label: const Text('من المعرض'),
              ),
            ),
          ],
        ),
      ],

      const SizedBox(height: 12),
      // ═══ كود التوثيق (يظهر بعد ضغط ارسال الرمز) ═══
      if (regToken != null) ...[
        const Divider(color: AppColors.line),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: regCodeReady ? AppColors.surface : AppColors.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: regCodeReady ? AppColors.success : AppColors.line,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (regCodeReady)
                const Icon(Icons.check_circle, size: 18, color: AppColors.success)
              else
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  regCodeReady
                      ? 'الرمز وصلك داخل المحادثة بالبوت — اكتبه بالأسفل'
                      : 'افتح تلغرام واضغط «مشاركة رقم هاتفي» — البوت يطابق رقمك ويرسل الرمز',
                  style: AppType.style(12, color: AppColors.muted, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openRegTelegram,
          icon: const Icon(Icons.telegram, size: 16, color: AppColors.info),
          label: Text('فتح تلغرام يدوياً 🔗',
              style: AppType.style(12, color: AppColors.primary, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        _Field(
          key: const ValueKey('code'),
          controller: code,
          hint: 'رمز التحقق (أرقام)',
          icon: Icons.message_outlined,
          isNumber: true,
          maxLen: 6,
          textInputAction: TextInputAction.done,
        ),
      ],
    ];
  }
"""

content = re.sub(
    r'List<Widget> _registerFields\(\) \{.*?Widget _regRoleBtn\(String v, String label\)',
    new_register_fields + "\n  Widget _regRoleBtn(String v, String label)",
    content,
    flags=re.DOTALL
)

with open('app/lib/features/auth/screens/login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
