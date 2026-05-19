'use strict';

/**
 * Admin authentication middleware.
 *
 * Reads ADMIN_SECRET from process.env (default: 'brainduel_admin').
 * Accepts the secret via:
 *   - Query param:  ?secret=xxx
 *   - Header:       x-admin-secret: xxx
 *
 * Returns 401 JSON if the secret is missing or wrong.
 */
module.exports = function adminAuth(req, res, next) {
  const expectedSecret = process.env.ADMIN_SECRET || 'brainduel_admin';

  const provided =
    req.query.secret ||
    req.headers['x-admin-secret'];

  if (!provided || provided !== expectedSecret) {
    return res.status(401).json({ error: 'Unauthorized: invalid or missing admin secret' });
  }

  return next();
};
