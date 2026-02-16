# Google Sign-In Setup Guide

This guide helps you configure Google OAuth for the Anganwadi Early Identification App across Android, iOS, and Web platforms.

## Step 1: Create a Google Cloud Project

1. Visit [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Google Sign-In API** for your project
4. Create OAuth 2.0 credentials:
   - Go to **Credentials** → **Create Credentials** → **OAuth client ID**
   - Choose **Android**, **iOS**, and **Web** as application types

---

## Step 2: Android Configuration

### 2a. Get Your SHA-1 Fingerprint

```bash
# Run this command to get debug SHA-1:
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Copy the **SHA-1** value.

### 2b. Create Android OAuth Credentials

1. In Google Cloud Console → Credentials
2. Create OAuth 2.0 Client ID for Android
3. Package name: `com.example.my_first_app`
4. SHA-1 fingerprint: [Paste the SHA-1 from 2a]
5. Copy the **Client ID** generated

### 2c. Update build.gradle.kts (Optional)

The build configuration already supports Google Play Services. No additional changes needed if using demo mode.

---

## Step 3: iOS Configuration

### 3a. Create iOS OAuth Credentials

1. In Google Cloud Console → Credentials
2. Create OAuth 2.0 Client ID for iOS
3. Bundle ID: `com.example.myFirstApp` (check in Xcode)
4. Copy the **Client ID** generated

### 3b. Update Info.plist

Add the following to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.example.myFirstApp</string>
    </array>
  </dict>
</array>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photos.</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera.</string>
```

Replace `YOUR_CLIENT_ID` with the iOS Client ID from 3a.

---

## Step 4: Web Configuration

### 4a. Create Web OAuth Credentials

1. In Google Cloud Console → Credentials
2. Create OAuth 2.0 Client ID for Web
3. Authorized redirect URIs:
   - `http://localhost:5000` (dev)
   - `http://localhost` (dev)
   - `https://yourdomain.com` (production)
4. Copy the **Client ID** generated

### 4b. Update web/index.html

Add this before the `<script>` tag in `web/index.html`:

```html
<script src="https://apis.google.com/js/platform.js" async defer></script>
<meta name="google-signin-client_id" content="YOUR_WEB_CLIENT_ID.apps.googleusercontent.com">
```

Replace `YOUR_WEB_CLIENT_ID` with your Web Client ID from 4a.

---

## Step 5: Update pubspec.yaml

Ensure the `google_sign_in` package is installed:

```yaml
dependencies:
  google_sign_in: ^6.1.0
```

Then run:
```bash
flutter pub get
```

---

## Step 6: Test

### For Android:
```bash
flutter run -d android
```

### For iOS:
```bash
flutter run -d ios
```

### For Web:
```bash
flutter run -d chrome
```

Click "Sign in with Google" button to test.

---

## Troubleshooting

### "MissingPluginException" Error
- **Cause**: Plugin not configured for your platform
- **Solution**: Follow the platform-specific steps above

### SHA-1 Mismatch on Android
- Ensure you used the correct debug keystore path
- For release builds, get the release keystore SHA-1

### "Platform not supported" on Web
- Ensure `web/index.html` has the Google platform script
- Clear browser cache and restart dev server

### iOS Bundle ID Mismatch
- Check `ios/Runner.xcodeproj/project.pbxproj` for actual bundle ID
- Update Info.plist accordingly

---

## Production Setup

For production release:

1. **Android**: Get SHA-1 from release keystore and register in Google Cloud Console
2. **iOS**: Register production bundle ID in Apple Developer and Google Cloud Console
3. **Web**: Register production domain and enable CORS if needed
4. Use environment-specific Google Cloud Projects (dev vs production)

---

For more details, visit [Google Sign-In Flutter Plugin Documentation](https://pub.dev/packages/google_sign_in)
