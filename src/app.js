import express from 'express';
import cookieParser from 'cookie-parser';
import pool from './db/pool.js';

const app = express();

app.use(express.json());
app.use(cookieParser());

app.get('/api/health', async (req, res) => {
  const { rows } = await pool.query('SELECT NOW() AS now');
  res.json({ ok: true, db: rows[0].now });
});

export default app;