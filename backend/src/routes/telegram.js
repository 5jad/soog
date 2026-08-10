import { Router } from 'express';
import { handleWebhook } from '../telegram.js';

const r = Router();

// نقطة الـ webhook — Vercel يرسل تحديثات البوت هنا
r.post('/webhook', async (req, res) => {
  try {
    await handleWebhook(req.body);
    res.json({ ok: true });
  } catch (e) {
    res.json({ ok: false, error: e.message });
  }
});

export default r;