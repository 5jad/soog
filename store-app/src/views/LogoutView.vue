<script setup>
/* ═══ خروج ═══ */
import { onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { useApp } from '../state';

const { logout, toast } = useApp();
const router = useRouter();

onMounted(() => {
  logout();
  toast('خرجت من حسابك — خلّصت التصفح');
  router.replace('/');
});
</script>

<template>
  <div class="loader-block" style="min-height:50vh"><div class="loader"></div></div>
</template>