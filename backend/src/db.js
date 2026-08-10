import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

pg.types.setTypeParser(1700, parseFloat);

const poolCfg = {
  connectionString: process.env.DATABASE_URL || 'postgres://zaboon@127.0.0.1:5434/zaboon',
  max: 10,
  connectionTimeoutMillis: 10000,
};
// Neon وقواعد السحابة تتطلب TLS — فعّله بـ PGSSL=true (على Vercel لازم true)
if (process.env.PGSSL === 'true') poolCfg.ssl = { rejectUnauthorized: false };

export const pool = new pg.Pool(poolCfg);

export const q = async (sql, params = []) => (await pool.query(sql, params)).rows;
export const one = async (sql, params = []) => (await pool.query(sql, params)).rows[0] || null;
export const tx = async (fn) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (e) {
    await client.query('ROLLBACK');
    throw e;
  } finally {
    client.release();
  }
};
