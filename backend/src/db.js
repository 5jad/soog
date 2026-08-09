import pg from 'pg';
import dotenv from 'dotenv';
dotenv.config();

pg.types.setTypeParser(1700, parseFloat);

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://zaboon@127.0.0.1:5434/zaboon',
  max: 10,
});

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
