import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const poolCfg = { connectionString: process.env.DATABASE_URL };
if (process.env.PGSSL === 'true') poolCfg.ssl = { rejectUnauthorized: false };
const pool = new pg.Pool(poolCfg);

const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
try {
  await pool.query(sql);
  console.log('✅ قاعدة البيانات انبنيت (schema.sql)');
} catch (e) {
  console.error('❌ فشل البناء:', e.message);
  process.exit(1);
}
await pool.end();
