<script setup>
/* ═══ تحويل للأدمن/خارجي ═══ */
import { onMounted } from 'vue';
const props = defineProps({ url: { type: String, default: '/admin' } });
onMounted(() => { window.location.href = props.url; });
</script>

<template>
  <div class="loader-block" style="min-height:50vh"><div class="loader"></div></div>
</template>