<script setup>
/* ═══ بطاقة الإطلالة — نفس تصميم بطاقة «إطلالات من مشترياتك» بالتطبيق ═══
   صورة البذرة + اسم القطعة + صور القطع + سعر/توافق + سهم */
import { computed } from 'vue';
import { useRouter } from 'vue-router';
import { S, isRaw, emojiOf, fmt } from '../api';

const props = defineProps({ o: { type: Object, required: true } });
const router = useRouter();

const seed = computed(() => props.o?.seed || {});
const of = computed(() => props.o?.outfit || {});
const slots = computed(() => of.value?.slots || []);
const seedImg = computed(() => S(seed.value.image));
const seedEmoji = computed(() => !seedImg.value || isRaw(seed.value.image) ? emojiOf(seed.value) : '');

const slotThumb = (s) => {
  const v = S(s.image);
  return { img: (v && !isRaw(s.image)) ? v : '', emoji: (!v || isRaw(s.image)) ? emojiOf(s) : '' };
};

const go = () => {
  const pid = Number(seed.value.id) || 0;
  if (pid) router.push(`/outfit/${pid}`);
};
</script>

<template>
  <article class="outfit-card" @click="go">
    <div class="pk">
      <img v-if="seedImg" :src="seedImg" alt="" loading="lazy" />
      <span v-else class="emoji">{{ seedEmoji }}</span>
    </div>
    <div class="in">
      <span class="name ellipsis">{{ seed.name || '' }}</span>
      <div class="thumbs">
        <template v-for="(s, i) in slots.slice(0, 4)" :key="i">
          <img v-if="slotThumb(s).img" :src="slotThumb(s).img" alt="" loading="lazy" />
          <span v-else class="emoji sm">{{ slotThumb(s).emoji }}</span>
        </template>
      </div>
      <span class="meta ellipsis">
        {{ slots.length }} قطع · {{ fmt(of.total || 0) }} · توافق {{ of.fit || 0 }}/100
      </span>
    </div>
    <span class="msm chev">chevron_left</span>
  </article>
</template>

<style scoped>
.outfit-card {
  width: 224px;
  height: 128px;
  padding: 10px;
  display: flex;
  align-items: center;
  gap: 10px;
  background: var(--surface);
  border: 1px solid var(--line);
  border-radius: 17px;
  cursor: pointer;
  flex-shrink: 0;
  transition: transform var(--t-fast) var(--ease), box-shadow var(--t-fast) var(--ease);
}
.outfit-card:hover { transform: var(--hover-raise); box-shadow: var(--sh-md); }
@media (hover: none) { .outfit-card:hover { transform: none; box-shadow: none; } }

.pk {
  width: 62px; height: 62px;
  border-radius: 14px;
  overflow: hidden;
  background: var(--img-ph);
  display: grid; place-items: center;
  flex-shrink: 0;
}
.pk img { width: 100%; height: 100%; object-fit: cover; }
.pk .emoji { font-size: var(--fs-3xl); }

.in { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
.in .name { font-size: var(--fs-xs); font-weight: 900; }
.thumbs { display: flex; gap: 3px; }
.thumbs img {
  width: 24px; height: 24px;
  border-radius: 7px;
  object-fit: cover;
  background: var(--img-ph);
}
.thumbs .emoji.sm { width: 24px; height: 24px; border-radius: 7px; background: var(--img-ph); display: grid; place-items: center; font-size: 12px; }
.meta { font-size: 9.5px; color: var(--muted); font-weight: 800; }
.chev { color: var(--primary); font-size: 22px; flex-shrink: 0; }
</style>