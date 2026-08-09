import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
try {
  await pool.query(sql);
  console.log('✅ قاعدة البيانات انبنيت (schema.sql)');
} catch (e) {
  console.error('❌ فشل البناء:', e.message);
  process.exit(1);
}
await pool.end();
