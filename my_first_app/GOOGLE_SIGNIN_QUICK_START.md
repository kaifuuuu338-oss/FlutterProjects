# Quick Google Sign-In Setup Steps

## For Immediate Testing (Demo Mode)

If you just want to test the app functionality without full OAuth setup:

### Disable Google Sign-In Button Temporarily

Comment out Google Sign-In and let it show a message:

Edit the Google button onPressed handlers in:
- `lib/screens/login_screen.dart` - `_loginWithGoogle()` method
- `lib/screens/signup_screen.dart` - `_registerWithGoogle()` method

Replace `_loginWithGoogle` with:
```dart
onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Configure Google OAuth in Google Cloud Console first'))
),
```

---

## For Production Setup

### Required Files & Steps:

1. **Get Google Cloud Credentials**
   - Visit: https://console.cloud.google.com/
   - Create project: "Anganwadi App"
   - Enable Google Sign-In API
   - Create OAuth credentials for: Android, iOS, Web

2. **For Each Platform**:

   **Android**:
   - File: `android/app/build.gradle.kts` (already configured)
   - Get SHA-1: Run command from setup guide
   - Add to Google Cloud: package + SHA-1

   **iOS**:
   - File: `ios/Runner/Info.plist`
   - Copy from: `ios/iOS_GoogleSignIn_Template.plist`
   - Update with your Client ID

   **Web**:
   - File: `web/index.html` (already updated)
   - Search for: `YOUR_WEB_CLIENT_ID`
   - Replace with your Web Client ID

3. **Run & Test**:
   ```bash
   flutter run
   ```
   Click "Sign in with Google" button

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| MissingPluginException | Follow platform setup above |
| SHA-1 doesn't match | Use correct debug keystore path: `%USERPROFILE%\.android\debug.keystore` |
| Bundle ID mismatch (iOS) | Verify in Xcode: Runner → General → Bundle Identifier |
| Web button not working | Clear browser cache, ensure `YOUR_WEB_CLIENT_ID` replaced in `web/index.html` |
| OAuth screen doesn't open | Check internet connection, plugin version |

---

## Reference Files

- **Full Setup Guide**: `GOOGLE_SIGNIN_SETUP.md`
- **iOS Template**: `ios/iOS_GoogleSignIn_Template.plist`
- **Web Config**: `web/index.html` (search for `google-signin-client_id`)

---

## Contact

For issues or questions about Google Sign-In configuration, refer to:
- [Google Sign-In Flutter Docs](https://pub.dev/packages/google_sign_in)
- [Google Cloud Console](https://console.cloud.google.com/)
