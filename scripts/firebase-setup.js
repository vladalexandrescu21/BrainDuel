#!/usr/bin/env node
/**
 * BrainDuel — Firebase Setup Script
 * Run: node scripts/firebase-setup.js
 *
 * What it does:
 * 1. Deploys Firestore security rules
 * 2. Deploys Firestore indexes
 * 3. Seeds initial shop items
 *
 * Prerequisites: firebase login (run once in terminal)
 */

const { execSync } = require('child_process');
const path = require('path');

const FIREBASE_DIR = path.join(__dirname, '..', 'firebase');

function run(cmd, cwd = FIREBASE_DIR) {
  console.log(`\n> ${cmd}`);
  try {
    execSync(cmd, { cwd, stdio: 'inherit' });
  } catch (e) {
    console.error(`Failed: ${e.message}`);
    process.exit(1);
  }
}

console.log('╔══════════════════════════════════════╗');
console.log('║   BrainDuel — Firebase Deploy        ║');
console.log('╚══════════════════════════════════════╝\n');

// Deploy Firestore rules + indexes
run('firebase deploy --only firestore');

console.log('\n✅ Firestore rules and indexes deployed!');
console.log('\nNext steps:');
console.log('  1. Go to Firebase Console → Authentication → Sign-in method');
console.log('  2. Enable: Email/Password, Google, Apple');
console.log('  3. Fill in app/lib/firebase_options.dart with your project values');
console.log('  4. Add GoogleService-Info.plist to app/ios/Runner/');
