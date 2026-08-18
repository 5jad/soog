<script setup>
import { useRouter } from 'vue-router';
const router = useRouter();
</script>

<template>
  <div class="container">
    <div class="page-plain">
      <div>
        <div class="big">404</div>
        <h1 class="h2" style="margin-block:var(--sp-3)">الصفحة مو موجودة</h1>
        <p class="text-muted" style="margin-block-end:var(--sp-5)">يمكن الرابط انكسر أو الصفحة انتقلت — رجّع للرئيسية</p>
        <button class="btn btn-primary btn-lg" @click="router.push('/')">الرئيسية</button>
      </div>
    </div>
  </div>
</template>