import re

with open('app/lib/features/auth/screens/login_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _modeLabel
content = re.sub(
    r'String get _modeLabel => mode == AuthMode\.login.*?\(regStage == 3 \? \'إنشاء المتجر\' : \'إنشاء الحساب\'\)\)\);',
    "String get _modeLabel => mode == AuthMode.login ? 'تسجيل الدخول' : (regToken == null ? 'متابعة للحصول على الرمز' : 'تأكيد وإنشاء الحساب');",
    content,
    flags=re.DOTALL
)

# Replace submit()
submit_logic = """Future<void> submit() async {
    if (mode == AuthMode.login) {
      _login();
      return;
    }
    if (regToken == null) {
      final p = phone.text.trim();
      if (p.length < 10) return toast(context, 'أدخل رقم هاتف صحيح', error: true);
      if (name.text.trim().length < 3) return toast(context, 'أدخل اسمك الكامل', error: true);
      if (password.text.length < 6) return toast(context, 'كلمة المرور 6 أحرف كحد أدنى', error: true);
      if (regRole == 'vendor') {
         if (storeName.text.trim().length < 3) return toast(context, 'أدخل اسم متجرك', error: true);
         if (selCat == null) return toast(context, 'اختر قسم المتجر', error: true);
         if (storeIdCard == null || storeIdCard!.isEmpty) return toast(context, 'ارفع صورة بطاقتك الوطنية — إلزامية للتوثيق', error: true);
      }
      return _regStart();
    } else {
      return _regSubmitAll();
    }
  }"""
content = re.sub(
    r'Future<void> submit\(\) async \{.*?if \(regStage == 3\) return _regSubmitStore\(\);\n  \}',
    submit_logic,
    content,
    flags=re.DOTALL
)

# Replace _regStart to not use regStage
content = re.sub(
    r'setState\(\(\) => regStage = 1\);',
    '',
    content
)

# Replace _resetReg regStage
content = re.sub(
    r'setState\(\(\) => regStage = 0\);',
    '',
    content
)

# Define _regSubmitAll and replace the old submit methods
reg_submit_all = """Future<void> _regSubmitAll() async {
    final t = regToken;
    final c = code.text.trim();
    if (t == null) return _resetReg();
    if (c.length < 4) return toast(context, 'اكتب الرمز اللي وصلك بالمحادثة', error: true);
    setState(() => loading = true);
    try {
      await Api.registerCode(t, c);
      final d = await Api.registerConfirm(
        token: t,
        name: name.text.trim(),
        password: password.text,
        referral: referral.text.trim(),
      );
      if (regRole == 'vendor') {
        final tk = (d?['token'] ?? '') as String;
        if (tk.isNotEmpty) await Api.saveToken(tk);
        await Api.post('/api/vendor/store', {
          'name': storeName.text.trim(),
          'description': storeDesc.text.trim(),
          'phone': storePhone.text.trim().isNotEmpty ? storePhone.text.trim() : phone.text.trim(),
          'address': storeAddress.text.trim(),
          if (selCat != null) 'category_id': selCat,
          if (selDist != null) 'district_id': selDist,
          if (slat != null) 'lat': slat,
          if (slng != null) 'lng': slng,
          if (storeLogo != null && storeLogo!.isNotEmpty) 'logo': storeLogo,
          if (storeCover != null && storeCover!.isNotEmpty) 'cover': storeCover,
        });
        await Api.post('/api/vendor/store/documents', {
          'type': 'national_id',
          'title': 'البطاقة الوطنية',
          'file_url': storeIdCard,
        });
        toast(context, 'انطلق متجرك — بانتظار توثيق الأدمن ⏳');
      }
      if (mounted) {
         _regPoll?.cancel();
         await _onSuccess(d);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      toast(context, e.message, error: true);
      if (e.message.contains('انتهت')) _resetReg();
    } catch (_) {
      if (!mounted) return;
      toast(context, 'تعذر الاتصال بالخادم', error: true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }"""

# Remove old methods: _regSubmitCode, _regSubmitDetails, _regSubmitStore
# We'll just replace _regSubmitCode with _regSubmitAll, and delete _regSubmitDetails and _regSubmitStore later by hand or regex.
content = re.sub(
    r'// ── المرحلة 1: رمز البوت ──.*?Future<void> _loadRegLists\(\) async \{',
    reg_submit_all + "\n\n  Future<void> _loadRegLists() async {",
    content,
    flags=re.DOTALL
)

with open('app/lib/features/auth/screens/login_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
