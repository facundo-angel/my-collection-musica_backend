import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pool from '../db/pool.js';

const USER_COLUMNS = 'id, username, email, display_name, bio, avatar_url';

const cookieOptions = {
  httpOnly: true,
  sameSite: 'lax',
  secure: process.env.NODE_ENV === 'production',
};

function toUser(row) {
  return {
    id: row.id,
    username: row.username,
    email: row.email,
    displayName: row.display_name,
    bio: row.bio,
    avatarUrl: row.avatar_url,
  };
}

function startSession(res, userId) {
  const token = jwt.sign({ userId }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN,
  });
  const { exp } = jwt.decode(token);
  res.cookie('token', token, { ...cookieOptions, expires: new Date(exp * 1000) });
}

function validateRegister(username, email, password) {
  if (typeof username !== 'string' || !/^[a-zA-Z0-9_]{3,30}$/.test(username)) {
    return 'El usuario debe tener entre 3 y 30 caracteres (letras, números o guion bajo)';
  }
  if (typeof email !== 'string' || email.length > 255 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return 'El correo no es válido';
  }
  if (typeof password !== 'string' || password.length < 8 || password.length > 72) {
    return 'La contraseña debe tener entre 8 y 72 caracteres';
  }
  return null;
}

export async function register(req, res) {
  const { username, email, password } = req.body ?? {};

  const error = validateRegister(username, email, password);
  if (error) return res.status(400).json({ error });

  const passwordHash = await bcrypt.hash(password, 10);

  try {
    const { rows } = await pool.query(
      `INSERT INTO users (username, email, password_hash, display_name)
       VALUES ($1, $2, $3, $1)
       RETURNING ${USER_COLUMNS}`,
      [username, email.toLowerCase(), passwordHash]
    );
    startSession(res, rows[0].id);
    res.status(201).json({ user: toUser(rows[0]) });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Ese usuario o correo ya está registrado' });
    }
    throw err;
  }
}

export async function login(req, res) {
  const { email, password } = req.body ?? {};
  if (typeof email !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Completá el correo y la contraseña' });
  }

  const { rows } = await pool.query(
    `SELECT ${USER_COLUMNS}, password_hash FROM users WHERE email = $1`,
    [email.trim().toLowerCase()]
  );
  const user = rows[0];

  if (!user || !(await bcrypt.compare(password, user.password_hash))) {
    return res.status(401).json({ error: 'Correo o contraseña incorrectos' });
  }

  startSession(res, user.id);
  res.json({ user: toUser(user) });
}

export function logout(req, res) {
  res.clearCookie('token', cookieOptions);
  res.status(204).end();
}

export async function me(req, res) {
  const { rows } = await pool.query(
    `SELECT ${USER_COLUMNS} FROM users WHERE id = $1`,
    [req.userId]
  );
  if (!rows[0]) return res.status(401).json({ error: 'No autenticado' });
  res.json({ user: toUser(rows[0]) });
}