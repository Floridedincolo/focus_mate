# Android Build & Upload Workflow Setup Guide

## What's been set up for you:

1. **GitHub Actions Workflow** (`.github/workflows/android-build.yml`)
   - Automatically triggers on push to `main` and pull requests
   - Builds both unsigned APK and App Bundle (AAB)
   - Uploads artifacts for download from Actions run

2. **Updated Android Build Config** (`android/app/build.gradle.kts`)
   - Now supports keystore signing when `key.properties` exists
   - Falls back to debug signing if no keystore is configured

## Quick Start (Unsigned Builds - No Secrets Needed)

Just push to `main` or open a PR. The workflow will:
1. ✅ Set up JDK 17 and Flutter
2. ✅ Build `APK` and `AAB` (unsigned)
3. ✅ Upload artifacts automatically

Download your builds from GitHub Actions → Your Run → Artifacts section.

---

## Setup for Signed Builds (Optional - For Release/Play Store)

### Step 1: Create a Keystore Locally (One-time)

Run this command on your machine (macOS/Linux):

```bash
keytool -genkeypair -v -keystore release-keystore.jks -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
```

You'll be prompted for:
- Keystore password (remember this!)
- Key password (can be same as keystore password)
- Your name, organization, etc.

**Important:** Do NOT commit `release-keystore.jks` to Git. We'll encode it as a secret.

### Step 2: Encode the Keystore as Base64

On macOS/Linux, run:

```bash
# macOS:
base64 release-keystore.jks > keystore.b64

# Linux:
base64 -w0 release-keystore.jks > keystore.b64
```

This creates `keystore.b64` with the encoded keystore. Open it:

```bash
cat keystore.b64
```

Copy the entire output.

### Step 3: Add Secrets to GitHub

1. Go to your GitHub repository
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add these 4 secrets:

| Secret Name | Value |
|------------|-------|
| `ANDROID_KEYSTORE` | The entire content of `keystore.b64` (the base64-encoded keystore) |
| `KEYSTORE_PASSWORD` | Your keystore password |
| `KEY_ALIAS` | The alias you used (e.g., `my-key-alias`) |
| `KEY_PASSWORD` | Your key password |

### Step 4: Test the Signed Build

Push to `main` or open a PR. The workflow will:
1. Detect the secrets
2. Decode the keystore
3. Create `android/key.properties` automatically
4. Build signed APK and AAB
5. Upload signed artifacts

---

## Where to Download Artifacts

After a workflow run completes:

1. Go to your GitHub repository
2. Click **Actions** tab
3. Open the latest workflow run
4. Scroll down to **Artifacts** section
5. Download:
   - `android-apk` → Your signed/unsigned APKs
   - `android-aab` → Your App Bundle (for Play Store)

Artifacts are kept for 30 days by default.

---

## Clean Up (Before Publishing to Play Store)

1. **Remove test/debug builds from your repo:**
   ```bash
   rm release-keystore.jks keystore.b64  # Don't commit these!
   ```

2. **When ready for Play Store:**
   - The signed APK/AAB from the workflow is ready to upload
   - Use Google Play Console to upload the AAB
   - Or use the APK for testing

---

## Troubleshooting

**Build fails with "keystore not found"?**
- Check that all 4 secrets are added correctly
- Verify `ANDROID_KEYSTORE` is the full base64 content (no line breaks)

**APK/AAB not showing in artifacts?**
- Check workflow logs for errors
- Ensure Flutter can build: `flutter build apk --release` works locally

**Want to change signing details later?**
- Update the secrets in GitHub → Settings → Secrets
- The next workflow run will use the new values

---

## Optional Enhancements

Add to the workflow later:
- Slack/email notifications on build completion
- Automated Play Store upload (requires Play Store JSON)
- APK signing report / size analysis
- Custom build variants (dev/staging/prod)

Enjoy your automated Android builds! 🚀

