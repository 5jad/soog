<script setup>
/* ═══ فوتر الموقع — عمود واحد موبايل ← 4 أعمدة ديسكتوب ═══ */
</script>

<template>
  <footer class="footer">
    <div class="footer-in">
      <div class="footer-brand">
        <span class="logo-text">زبون</span>
        <p>منصة متاجر محلية لمنطقة الكوت وواسط — تسوّق من محلات مدينتك، توصيل سريع 30–60 دقيقة، ادفع كاش عند الاستلام.</p>
        <div class="footer-social">
          <a class="icon-btn" href="#" aria-label="تيليجرام" @click.prevent><span class="msm">send</span></a>
          <a class="icon-btn" href="#" aria-label="إنستغرام" @click.prevent><span class="msm">photo_camera</span></a>
          <a class="icon-btn" href="#" aria-label="فيسبوك" @click.prevent><span class="msm">thumb_up</span></a>
        </div>
      </div>
      <div class="footer-col">
        <h4>تسوق</h4>
        <RouterLink to="/prods">كل المنتجات</RouterLink>
        <RouterLink to="/offers">العروض</RouterLink>
        <RouterLink to="/stores">المتاجر</RouterLink>
        <RouterLink to="/search">البحث</RouterLink>
      </div>
      <div class="footer-col">
        <h4>حسابي</h4>
        <RouterLink to="/account">الملف الشخصي</RouterLink>
        <RouterLink to="/orders">طلباتي</RouterLink>
        <RouterLink to="/points">نقاطي</RouterLink>
        <RouterLink to="/fav">المفضلة</RouterLink>
      </div>
    </div>
    <div class="footer-bottom">زبون © 2026 — كل الحقوق محفوظة</div>
  </footer>
</template>