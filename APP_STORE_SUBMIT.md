# App Store Connect — WKCC Perks submit pack

Use this checklist to finish App Store listing and submission. Backend ops were verified 2026-07-29 (`wbzmpylhlsikgzpmfksl`). Live auth is on (`AppConfig.useMockAuth = false`).

## URLs (App Information)

| Field | Value |
|---|---|
| **Support URL** | `https://chambermaster.wilmettekenilworth.com/contact/` |
| **Marketing URL** (optional) | `https://www.wilmettekenilworth.com` |
| **Privacy Policy URL** | `https://www.wilmettekenilworth.com/wkcc-perks-privacy/` (hosted; entered in ASC) |

### Host the privacy policy (required before submit)

**Done (2026-08-11):** Public HTTPS privacy policy is live and set in App Store Connect.

Source HTML remains at [`docs/app-store/privacy-policy.html`](docs/app-store/privacy-policy.html).

---

## App Privacy questionnaire (suggested answers)

**Done:** App Privacy answers saved in App Store Connect (2026-08-11). Reference answers used:

| Data type | Collected? | Linked to user? | Used for tracking? | Purpose |
|---|---|---|---|---|
| Email address | Yes | Yes | No | App Functionality, Account Management |
| Name / business name | Yes | Yes | No | App Functionality |
| Photos / imagery (business logo) | Yes (user-provided) | Yes | No | App Functionality |
| Product interaction (in-app use of perks UI) | Optional / No unless you add analytics | — | No | — |
| Crash data | Only if you enable Apple diagnostics / third-party crash tools | Prefer No / Not linked | No | App Functionality |

No advertising SDKs and no third-party tracking in the current app.

---

## Age rating / compliance

| Question | Suggested answer |
|---|---|
| Age rating | **4+** (business member directory + promotions; no restricted content) |
| Made for Kids | **No** |
| Encryption / Export compliance | Uses standard HTTPS / iOS encryption only → typically **Yes** uses encryption, and **exempt** (HTTPS only) — confirm in ASC wizard |
| Content rights | You have rights to chamber branding and member-submitted promo content |

---

## Screenshots

Capture on a physical device or Simulator for required sizes (at least **6.7"** iPhone and any required iPad if the app supports iPad).

Suggested set (5–6 frames):

1. Home (bento + partners)
2. Deals list
3. Deal / perk detail (redemption passport)
4. Businesses directory
5. Business detail
6. Login / Connect membership (optional)

Store files locally (PNG/JPEG). Upload in App Store Connect → Prep for Submission → Screenshots.

---

## Sign-in Information (App Review)

**Sign-in required:** Yes

| Field | Value |
|---|---|
| Username | Your review mailbox, e.g. `wkccperksconnect@gmail.com` |
| Password | The **email account** password (reviewers open the inbox for the OTP) |

### Notes (paste into App Review Notes)

```
WKCC Perks is a private member app for Wilmette/Kenilworth Chamber of Commerce businesses. Sign-in uses email + one-time passcode (OTP), not a traditional password.

DEMO / REVIEW LOGIN
1. On the login screen, enter Username (email): wkccperksconnect@gmail.com
2. Tap Continue. A 6-digit code is emailed to that address (subject: "Your WKCC Perks sign-in code").
3. Open the review inbox with the Password provided in Sign-in Information (this is the email account password, not an in-app password).
4. Enter the 6-digit code in the app, then Confirm membership on the confirmation screen.

WHAT TO TEST
• Home — featured / partner perks
• Deals — browse, search, open a perk detail
• Businesses — directory and business detail
• Profile — member card / membership info; optional: edit business profile fields
• Submit a promotion (member flow) if reviewing that feature

NOTES
• Only active chamber membership emails can request a code. This review account is verified in the chamber, may require additional verification via email.
• Codes expire after a short time; use Resend if needed.
• Push notifications may be limited in the review build.
• No special in-app settings are required.

Contact for review issues: info@wilmettekenilworth.com / 847-251-3800
```

Replace the username if your review email differs. Optional attachment: short PDF walkthrough (`.pdf`) of Connect → Verify → Confirm → Home.

---

## Version / build checklist

Before uploading:

- [x] `AppConfig.useMockAuth = false`
- [x] Prod secrets / edge functions / migrations verified
- [x] Release archive built locally (`build/WKCCPerks.xcarchive`, 2026-07-29)
- [x] Privacy policy HTML hosted at a public HTTPS URL and entered in ASC
- [x] Support URL set to chamber contact page
- [x] App Privacy answers saved
- [x] Screenshots uploaded (if not already)
- [x] Review username / password / notes filled (if not already)
- [x] **Install Xcode 26+** (required for ASC upload — iOS 26 SDK)
- [x] Set `APNS_PRODUCTION=true` before TestFlight / App Store builds
- [ ] Re-archive with Xcode 26, upload, then **Submit to App Review**

---

## Archive and upload (Xcode)

### Blocker (verified 2026-07-29)

Local archive **succeeded** at `build/WKCCPerks.xcarchive`, but App Store Connect **rejected the upload**:

> SDK version issue. This app was built with the iOS 18.5 SDK. All iOS and iPadOS apps must be built with the **iOS 26 SDK or later**, included in **Xcode 26 or later**.

This machine currently has **Xcode 16.4** (iOS 18.5 SDK) only. Before you can upload or submit:

1. Install **Xcode 26+** from the Mac App Store or [developer.apple.com/download](https://developer.apple.com/download/).
2. `sudo xcode-select -s /Applications/Xcode.app` (or the Xcode 26 app path).
3. Re-archive and upload (commands below).

Export options for upload (after Xcode 26): [`docs/app-store/ExportOptions.plist`](docs/app-store/ExportOptions.plist).

### After Xcode 26 is installed

1. Open `Wilmette Kenilworth Perks.xcodeproj` in Xcode 26.
2. Select scheme **Wilmette Kenilworth Perks**, destination **Any iOS Device (arm64)**.
3. Product → **Archive**.
4. In Organizer → Distribute App → **App Store Connect** → Upload.
5. After processing, in App Store Connect attach the build to the version, complete listing fields above, then **Add for Review** → **Submit to App Review**.

### CLI (Xcode 26+)

```bash
cd "/Users/bodehubbard/Documents/SWE/Wilmette Kenilworth Perks"
xcodebuild -scheme "Wilmette Kenilworth Perks" \
  -project "Wilmette Kenilworth Perks.xcodeproj" \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath "build/WKCCPerks.xcarchive" \
  archive

xcodebuild -exportArchive \
  -archivePath "build/WKCCPerks.xcarchive" \
  -exportOptionsPlist "docs/app-store/ExportOptions.plist" \
  -exportPath "build/WKCCPerks-export" \
  -allowProvisioningUpdates
```

---

## After submit

Watch App Review for:

- OTP / inbox access issues (resend notes or confirm mailbox password)
- Photos usage string (`NSPhotoLibraryUsageDescription`) if they reject logo picker
- Sparse directory content (expected early; not a blocker if flows work)
