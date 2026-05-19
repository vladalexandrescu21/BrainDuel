'use strict';

require('dotenv').config();

const SKIP_AUTH = process.env.SKIP_AUTH === 'true';
const hasFirebaseConfig =
  process.env.FIREBASE_PROJECT_ID &&
  process.env.FIREBASE_CLIENT_EMAIL &&
  process.env.FIREBASE_PRIVATE_KEY;

let _verifyIdToken;

if (SKIP_AUTH || !hasFirebaseConfig) {
  console.log('[Firebase] SKIP_AUTH mode — using mock token verification');

  /**
   * Mock verifyIdToken: decodes nothing, returns a fake uid derived from the token string.
   * Useful for local development / testing without real Firebase credentials.
   * @param {string} token
   * @returns {Promise<{ uid: string, name?: string }>}
   */
  _verifyIdToken = async (token) => {
    return { uid: `dev_${token}`, name: token };
  };
} else {
  let admin;
  try {
    admin = require('firebase-admin');

    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: process.env.FIREBASE_PROJECT_ID,
          clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
          // Replace escaped newlines that may come from .env files
          privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }),
      });
    }

    console.log('[Firebase] Admin SDK initialised successfully');

    /**
     * Verify a Firebase ID token and return its decoded payload.
     * @param {string} token
     * @returns {Promise<admin.auth.DecodedIdToken>}
     */
    _verifyIdToken = async (token) => {
      return admin.auth().verifyIdToken(token);
    };
  } catch (err) {
    console.error('[Firebase] Failed to initialise Admin SDK:', err.message);
    console.warn('[Firebase] Falling back to mock token verification');

    _verifyIdToken = async (token) => {
      return { uid: `dev_${token}`, name: token };
    };
  }
}

/**
 * Verify a Firebase ID token (or mock token in dev mode).
 * @param {string} token
 * @returns {Promise<{ uid: string, name?: string }>}
 */
async function verifyIdToken(token) {
  return _verifyIdToken(token);
}

module.exports = { verifyIdToken };
