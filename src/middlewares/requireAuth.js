import jwt from 'jsonwebtoken';

export default function requireAuth(req, res, next) {
  const token = req.cookies.token;
  if (!token) return res.status(401).json({ error: 'No autenticado' });

  try {
    req.userId = jwt.verify(token, process.env.JWT_SECRET).userId;
  } catch {
    return res.status(401).json({ error: 'No autenticado' });
  }
  next();
}