# IBD Aide — App Store Submission Package

Companion to `04-AppStore-Listing.md` (name, subtitle, promo text, full description, keywords).
This file covers everything else App Store Connect asks for.

---

## Brief description (for quick use — App Store Connect uses the full description from doc 04)

> IBD Aide is a free, private companion for Crohn's disease and ulcerative colitis. Log symptoms in seconds, scan foods for common IBD triggers, track meds and IV infusions, and share a clean PDF summary with your doctor. All health data stays encrypted on your iPhone — no accounts, no ads, ever.

## Screenshots (in `appstore-screenshots/`)

| File | Story told |
|---|---|
| `screenshot-1.png` | Log symptoms in seconds (Home, Bristol quick-tap, score) |
| `screenshot-2.png` | Spot flare patterns early (Trends, triggers) |
| `screenshot-3.png` | Know before you eat (Scan verdict, flare mode) |
| `screenshot-4.png` | Stay on top of treatment (Care, infusions, questions) |
| `screenshot-5.png` | Yours to share. Yours alone. (Report + privacy) |

- Size: 1320×2868 px — the required 6.9″ iPhone size; App Store Connect auto-scales it for smaller devices. Upload in the order above (screenshot 1 carries the most weight).
- **Important:** these are styled design mockups matching the built UI. Apple requires screenshots to reflect the actual running app — before submission, load the app with the same sample data and capture real screenshots (Simulator ▸ Cmd+S, or device), or at minimum verify the mockups are pixel-faithful to the final UI. The caption-on-brand-background format itself is fine and common.

## App Store Connect — remaining fields

| Field | Value |
|---|---|
| Primary language | English (U.S.) |
| Bundle ID | com.ibdaide.app (must match the registered App ID) |
| SKU | IBDAIDE001 |
| Price | Free (all territories, or U.S.-only for launch per spec) |
| Primary category | **Medical** (App Store Connect ▸ App Information ▸ Category) |
| Secondary category | Health & Fitness |
| License agreement | Standard Apple EULA |
| Content rights | Does not contain third-party content requiring rights |

## Age rating questionnaire

Answer **None/No** to everything except: **Medical/Treatment Information → Infrequent/Mild** (the app presents health-tracking and dietary guidance). Result: **12+**. Not made for kids; no ads; no unrestricted web access needs declaring (SFSafariViewController news reader is fine).

## App Privacy section

- Data collection: **Data Not Collected** (nothing leaves the device linked to identity; no analytics, no accounts, no tracking).
- Privacy policy URL: host `website/privacy.html` and paste the URL.

## App Review Information

- Sign-in required: **No** (no accounts — check "Sign-in not required").
- Contact: Trisha Samanpure · trisha.rsny@gmail.com · phone number required — fill in.
- **Notes for reviewer (paste verbatim):**

> IBD Aide is a personal health tracker for people with Inflammatory Bowel Disease. All health data is stored only on the device, encrypted at rest via iOS Data Protection; the app has no server, no accounts, and no analytics. The only network requests are: (1) Open Food Facts product lookups sending barcode digits or a user-typed food name only, (2) public RSS news feeds with no identifiers, (3) Apple Maps search for the restroom finder. Food-safety results are informational estimates compiled from Crohn's & Colitis Foundation and IOIBD dietary guidance, with a persistent not-medical-advice disclaimer (onboarding, results screens, and description). The doctor-report PDF is shared only through the system share sheet by the user. The app is fully testable immediately after onboarding with no credentials; to see the food scanner, scan any grocery barcode or photograph a dish.

## Version release

- Version 1.0, build 1. "What's New" text for v1.0:

> Welcome to IBD Aide — private symptom, food, medication, and appointment tracking for Crohn's disease and ulcerative colitis. Everything stays encrypted on your phone.

- Release option: **Manually release this version** (recommended for a first launch so you control timing after approval).

## Pre-flight checklist (final)

- [ ] App ID registered (Data Protection: Complete; nothing else — see earlier notes)
- [ ] Export compliance: "None of the algorithms" / `ITSAppUsesNonExemptEncryption = NO` in target Info
- [ ] Privacy policy + support pages hosted; URLs pasted into App Store Connect
- [ ] Effective date set in privacy.html
- [ ] Real screenshots captured from the running app
- [ ] Dietitian review applied to food rules (`IBD-Aide-Food-Rules-Review.xlsx`)
- [ ] Curated news feed URLs replacing the Google News placeholder (`NewsFeedService.swift`)
- [ ] Full checklist in `01-iOS-Spec.md` §5 walked once more before pressing Submit
