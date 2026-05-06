#!/usr/bin/env node

/**
 * Font Setup Script
 *
 * This script helps verify that Poppins fonts are properly installed.
 * Run this after adding font files to check if everything is configured correctly.
 */

const fs = require('fs');
const path = require('path');

const fontsDir = path.join(__dirname, '../src/assets/fonts');
const requiredFonts = [
  'Poppins-Regular.ttf',
  'Poppins-SemiBold.ttf',
];

console.log('🔍 Checking Poppins font files...\n');

let allFontsPresent = true;

requiredFonts.forEach(font => {
  const fontPath = path.join(fontsDir, font);
  if (fs.existsSync(fontPath)) {
    const stats = fs.statSync(fontPath);
    console.log(`✅ ${font} found (${(stats.size / 1024).toFixed(2)} KB)`);
  } else {
    console.log(`❌ ${font} NOT FOUND`);
    allFontsPresent = false;
  }
});

console.log('\n');

if (allFontsPresent) {
  console.log('✅ All Poppins fonts are installed!');
  console.log('\nNext steps:');
  console.log('1. Run: npx react-native-asset (for Android)');
  console.log('2. Run: cd ios && pod install && cd .. (for iOS)');
  console.log('3. Rebuild your app');
} else {
  console.log('❌ Some fonts are missing!');
  console.log('\nPlease download Poppins fonts from:');
  console.log('https://fonts.google.com/specimen/Poppins');
  console.log('\nSee client/src/assets/fonts/README.md for detailed instructions.');
  process.exit(1);
}

