# Poppins Font Installation Guide

This project uses the Poppins font family. You need to download and add the font files to this directory.

## Required Font Files

Download the following font files and place them in this directory (`client/src/assets/fonts/`):

1. **Poppins-Regular.ttf** - Regular weight font
2. **Poppins-SemiBold.ttf** - SemiBold weight font

## Where to Download

You can download Poppins fonts from:

1. **Google Fonts** (Recommended):
   - Visit: https://fonts.google.com/specimen/Poppins
   - Click "Download family"
   - Extract the ZIP file
   - Copy `Poppins-Regular.ttf` and `Poppins-SemiBold.ttf` to this directory

2. **Direct Download**:
   - Poppins Regular: https://github.com/google/fonts/raw/main/ofl/poppins/Poppins-Regular.ttf
   - Poppins SemiBold: https://github.com/google/fonts/raw/main/ofl/poppins/Poppins-SemiBold.ttf

## File Naming

**IMPORTANT**: The font files must be named exactly as:
- `Poppins-Regular.ttf` (case-sensitive)
- `Poppins-SemiBold.ttf` (case-sensitive)

## After Adding Fonts

Once you've added the font files:

1. **For iOS**:
   ```bash
   cd ios
   pod install
   cd ..
   ```

2. **For Android**:
   ```bash
   npx react-native-asset
   ```

3. **Rebuild the app**:
   ```bash
   # For iOS
   npx react-native run-ios
   
   # For Android
   npx react-native run-android
   ```

## Verification

The fonts are configured in:
- `client/src/utils/Constants.tsx` - Font enum definitions
- `client/ios/blinkit/Info.plist` - iOS font registration (Note: folder name is still blinkit, but app is SonicKart)
- `client/react-native.config.js` - Asset linking configuration

After adding the fonts and rebuilding, the app should use Poppins fonts throughout.

