# IBD Aide — Android App (v1.0 source)

Native Kotlin / Jetpack Compose implementation of `02-Android-Spec.md` + `00-Product-Spec-Common.md`.
Built after the iOS app, incorporating its lessons (see below).

## Build & run

1. **Requirements:** Android Studio Ladybug (2024.2) or newer, JDK 17 (bundled with AS).
2. Open the `android/` folder in Android Studio.
3. **One-time:** the Gradle wrapper JAR isn't checked in. Either let Android Studio offer to
   configure Gradle on first sync, or run `gradle wrapper` once from a terminal with Gradle installed
   (`gradle-wrapper.properties` pins Gradle 8.10.2).
4. Sync, pick a device/emulator (minSdk 28 / Android 9+), and Run.

Barcode scanning uses Google Play services (present on any Play-certified device/emulator with Play Store image). Dish photos use the system camera — **no CAMERA permission needed at all**, which keeps the Play Store data-safety story clean.

## Lessons from the iOS build, applied here from day one

- **In-app dish photo capture** (the iOS v1 gap): Scan ▸ Dish photo opens the camera directly (`TakePicturePreview`), with photo-library pick as secondary.
- **Full food knowledge base** (CCF + IOIBD sourced, 34 rules / 16 safe foods / 58 dishes) ported verbatim from iOS — same verdicts on both platforms, plus the Lookup tab with Open Food Facts name search.
- **Identical score calculators & test vectors** — `app/src/test/.../ScoringTest.kt` runs the same vectors as the iOS `ScoringTests.swift` (run with `./gradlew test`).
- **Same encrypted-export format** — salt(16) + nonce(12) + AES-256-GCM, PBKDF2 600k, same JSON field names → cross-platform restore is feasible in v1.1.
- **No API keys, minimal dependencies** — restroom finder uses a maps `geo:` intent instead of the Places SDK; charts are hand-drawn Compose Canvas; the project builds with nothing but Google/Maven Central artifacts.

## Spec mapping

| FR | Where |
|---|---|
| FR-1/2/12 | `ui/HomeScreen.kt`, `ui/TrendsScreen.kt`, `core/Scoring.kt`, `core/Analytics.kt` |
| FR-3 | Home quick-log + Scan "Log as meal" |
| FR-4 | `ui/ScanScreen.kt` (Play services code-scanner) + `core/OpenFoodFactsClient.kt` |
| FR-5 | `ui/ScanScreen.kt` + `core/IngredientInference.kt` (ML Kit OCR + image labeling, on-device) |
| FR-6/7 | `ui/CareScreen.kt` (+ colonoscopy prep, question builder) |
| FR-8 | `ui/MedsSection.kt` + `core/Reminders.kt` (notification Taken/Skip actions) |
| FR-9 | `ui/MoreScreen.kt` + `core/PdfReportBuilder.kt` (share sheet via FileProvider) |
| FR-10 | `core/NewsFeedService.kt` (on-demand refresh) |
| FR-11 | Maps `geo:` intent (transient, nothing stored) |
| FR-13 | `MainActivity.kt` — BiometricPrompt + device-credential fallback, `FLAG_SECURE`, generic notifications |
| FR-14a | Auto Backup + device-transfer rules (`res/xml/`), E2E-encrypted with device PIN on Android 9+; covers Samsung Smart Switch |
| FR-14b | `core/ExportManager.kt` + Settings (SAF file export/import) |
| FR-15 | `core/FoodKnowledgeBase.kt` + `ui/FoodLookupSection.kt` |

## Documented deviations from `02-Android-Spec.md` (v1 pragmatism)

1. **SQLCipher deferred.** v1 uses plain Room; at-rest encryption is provided by Android file-based encryption (standard since Android 10, satisfies Play's health-app encryption-at-rest requirement), and Auto Backup stays seamlessly restorable. The spec's SQLCipher + PIN-recovery design is a pre-release hardening task — revisit before Play submission if you want app-level encryption on top of FBE.
2. **Gemini Nano / ML Kit GenAI deferred.** Dish analysis uses ML Kit image labeling + OCR (all devices). The GenAI image-description API (Gemini Nano on Pixel 8+/Galaxy S24+, same runtime as Galaxy AI) is the designed upgrade path in `IngredientInference.kt`.
3. **Places SDK swapped for a `geo:` intent** — avoids an API key and any Google Cloud account; better privacy story too.
4. **Appointment date entry** uses quick-adjust chips rather than a Material date/time picker — swap in `DatePickerDialog`/`TimePickerDialog` for polish.
5. **targetSdk 35** (current Play requirement); bump to 36 when AGP stable supports it.

## Before Play submission

### Category & account strategy (personal account, no "Medical" category)

- **Store category: Lifestyle** — the best truthful fit that avoids the Medical category (which requires an organization account). Alternative: Productivity. Position the listing as a *personal wellness & symptom journal*: lead with journaling, meal diary, reminders, and appointment organizing; keep the medical disclaimer; make no diagnosis/treatment claims.
- **Honest caveat:** Google's health-apps rules key off app *features and the Health Apps Declaration*, not just the category picker. Fill the declaration truthfully (wellness/self-tracking; not a medical device). If Play nonetheless requires an organization account for the declared features, the options are: (a) register an inexpensive single-member LLC and convert the account, (b) launch iOS first and hold Android until then, or (c) distribute the Android APK directly from your website in the interim (Android permits sideloading; keep the same privacy policy).
- **Listing-copy enhancements for Lifestyle positioning:** title "IBD Aide — Wellness Journal"; short description (≤80 chars) e.g. "Private symptom, food & appointment journal for gut health"; avoid the words "medical", "treatment", "diagnosis", "patient" in the listing; the in-app content (scores, citations, disclaimers) stays unchanged.

### Remaining checklist

- See `02-Android-Spec.md` §5 (health declaration, data safety form, privacy policy URL — `website/privacy.html` is ready to host).
- Replace the placeholder Google News feed in `NewsFeedService.kt` with your curated list.
- Apply GI-dietitian feedback from `IBD-Aide-Food-Rules-Review.xlsx` to `FoodKnowledgeBase.kt` (mirror any changes to the iOS copy).
- Decide on deviation #1 (SQLCipher) and test Auto Backup restore on a second device including Smart Switch.
- Store listing: reuse `04-AppStore-Listing.md` copy (Play has no subtitle; short description ≤80 chars).
