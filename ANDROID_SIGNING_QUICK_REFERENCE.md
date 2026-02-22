# Android Signing Setup - Quick Reference

## For Signed Builds (Release/Play Store)

### 1️⃣ Generate Keystore (Do This Once)

```bash
keytool -genkeypair -v -keystore release-keystore.jks \
  -alias my-key-alias \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

This will ask for:
- **Keystore Password**: e.g., `MySecurePassword123`
- **Key Password**: e.g., `MySecurePassword123` (can be same)
- Name, organization, location, etc.

### 2️⃣ Encode and Copy

```bash
# macOS
base64 release-keystore.jks > keystore.b64
cat keystore.b64  # Copy this entire output
```

### 3️⃣ Add to GitHub Secrets

Go to: **GitHub → Your Repo → Settings → Secrets and variables → Actions**

Add these 4 secrets:

```
ANDROID_KEYSTORE = [paste entire keystore.b64 content]
KEYSTORE_PASSWORD = MySecurePassword123
KEY_ALIAS = my-key-alias
KEY_PASSWORD = MySecurePassword123
```

### 4️⃣ Push and Watch

```bash
git add .
git commit -m "Setup Android signing"
git push origin main
```

Watch GitHub Actions build your signed APK/AAB! 🎉

---

## Download Your Build

**Actions → Latest Run → Artifacts:**
- `android-apk` - signed APK(s)
- `android-aab` - signed App Bundle

Ready for Play Store! 🚀

---

## Security Notes

⚠️ **Do NOT commit:**
- `release-keystore.jks`
- `keystore.b64`
- `android/key.properties`

✅ **DO use GitHub Secrets** for all sensitive data.

---

## Local Testing (Optional)

Test locally before pushing:

```bash
# Create key.properties in android/ directory
cat > android/key.properties << 'EOF'
storeFile=../release-keystore.jks
storePassword=MySecurePassword123
keyAlias=my-key-alias
keyPassword=MySecurePassword123
EOF

# Build signed APK
flutter build apk --release

# Clean up (don't commit!)
rm android/key.properties
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

