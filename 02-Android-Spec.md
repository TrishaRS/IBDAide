# IBD Aide — Android Platform Specification

**Companion to:** `00-Product-Spec-Common.md` (FR-x references below). This document is self-sufficient for an Android build team/tool when paired with the common spec.
**Spec v1.0 · July 2026**

---

## 1. Targets & Stack

| Item | Choice |
|---|---|
| Language | Kotlin 2.x, coroutines/Flow |
| UI | Jetpack Compose, Material 3; MVVM + Hilt DI |
| minSdk | 28 (Android 9 — required for client-side-encrypted Auto Backup) |
| targetSdk | Latest required by Play (36 as of 2026) |
| AI feature gate | ML Kit GenAI / Gemini Nano via AICore on supported devices (Pixel 8+, Galaxy S24+ and newer Galaxy AI devices); graceful fallback below |
| Persistence | Room + **SQLCipher** (AES-256), key wrapped by Android Keystore |
| Secrets | Android Keystore + `EncryptedSharedPreferences` |
| Dependency policy | Google/Jetpack + SQLCipher + ML Kit only; no analytics/ad SDKs |

## 2. Security & Privacy Architecture

### 2.1 Encryption at rest (NFR-1)
- Room database encrypted with SQLCipher; database key is random 256-bit, encrypted (wrapped) by a non-exportable Android Keystore key.
- **Backup-critical detail:** Keystore keys never leave the device, so the *wrapped* DB key cannot be restored on a new phone. Therefore keep a second copy of the DB key encrypted with a key derived from the user's app PIN/passphrase (PBKDF2) inside the backed-up prefs — on restore to a new device, user enters PIN → DB key recovered → re-wrapped with the new device's Keystore. This makes FR-14a actually work; without it, restored data is unreadable.
- Scan photos stored app-private (`filesDir`), deleted after inference by default; caches in `cacheDir` (excluded from backup).

### 2.2 App lock — biometrics (FR-13)
- `androidx.biometric.BiometricPrompt`, `BIOMETRIC_STRONG or DEVICE_CREDENTIAL` (fingerprint/face with PIN/pattern fallback). Optional app-level PIN (salted hash in `EncryptedSharedPreferences`).
- Auto-lock on `onStop` past grace period; `FLAG_SECURE` on all activities (blocks screenshots/recents thumbnail of health data).
- Notifications use generic text ("You have a reminder") — no health content on lock screen.

### 2.3 Backup & migration (FR-14)
- **(a)** Android **Auto Backup** (`android:allowBackup="true"`, `android:dataExtractionRules`): include Room DB + prefs; exclude caches and Keystore-wrapped blobs that are device-bound. On Android 9+ backups are end-to-end encrypted with the device PIN. Also declare `android:fullBackupContent` for pre-12 devices. Device-to-device transfer (cable/Smart Switch) uses the same rules — covers Samsung migrations.
- **(b)** Manual export: common JSON schema → AES-256-GCM with PBKDF2 (≥600k iterations) passphrase key → single `.ibdaide` file via Storage Access Framework (`ACTION_CREATE_DOCUMENT`). Import validates schema version.
- Test restore explicitly on a second device including a Samsung (Smart Switch path).

### 2.4 Privacy disclosures
- Data safety form: health data collected **on-device only, not shared**; declare the three network calls (§6) as not linked to identity.
- No `AD_ID` permission; no analytics.

## 3. Feature Implementation Map

| FR | Android implementation |
|---|---|
| FR-1/2/12 | Compose forms + Vico/Compose Charts; score calculators as a pure-Kotlin module with shared test vectors |
| FR-3 | CameraX for photos; quick-add water via home-screen shortcut (`ShortcutManager`) |
| FR-4 | **ML Kit Barcode Scanning** (on-device) via CameraX → Open Food Facts REST (barcode only) → local rules engine |
| FR-5 | **Primary:** ML Kit GenAI image description / Gemini Nano prompt via AICore (fully on-device) → structured ingredient list → rules engine. On Samsung Galaxy AI devices this is the same Gemini Nano runtime — no separate Samsung SDK needed. **Fallback:** ML Kit Text Recognition (OCR) on ingredient labels → rules engine; dish-photo inference disabled with explanatory UI |
| FR-6 | Detail screens; address opens `geo:` intent (Google Maps / Samsung Maps) |
| FR-7 | `AlarmManager.setExactAndAllowWhileIdle` + `POST_NOTIFICATIONS` (runtime permission, Android 13+); `SCHEDULE_EXACT_ALARM` justification: user-scheduled medical reminders (Play-permitted use case); colonoscopy-prep checklist |
| FR-8 | Notification actions ("Taken"/"Skip"); refill countdown in model layer |
| FR-9 | `android.graphics.pdf.PdfDocument` composed from Compose-rendered bitmaps → `Intent.ACTION_SEND` share sheet (user sends via own Gmail/Messages) |
| FR-10 | `WorkManager` periodic fetch (≤2×/day) of curated feeds; local notification on new items; no push/FCM, no server |
| FR-11 | Google Places/Maps SDK "public restroom" search near fused location (`ACCESS_COARSE/FINE_LOCATION`, while-in-use only) |

## 4. UI Requirements (NFR-4/5/6)

- Bottom navigation: **Home** (today + quick log), **Trends**, **Scan**, **Care** (team/appointments/meds), **More** (report, news, toilet finder, settings).
- Quick log ≤2 taps post-unlock; BM log as FAB on Home.
- `WindowSizeClass` adaptive layouts: compact phones (5″) → 6.9″ flagships → Galaxy Z Flip/Fold (cover + inner screens); primary screens fit without scrolling on 6.1″+.
- Material You dynamic color with a calm brand accent fallback; dark theme; TalkBack labels; font scaling to 200%; 48 dp touch targets.
- Test on One UI (Samsung), Pixel stock, and one budget OEM skin.

## 5. Google Play Compliance Checklist (Health Apps policy, 2025–2026 rules)

- [ ] **Store category: Lifestyle** (personal wellness journal positioning; "Medical" category avoided — it triggers the organization-account requirement). Listing copy frames the app as a personal wellness & symptom journal; no diagnosis/treatment claims.
- [ ] **Health Apps Declaration** in Play Console: note this is triggered by app *features*, not the category picker. Answer honestly (wellness/tracking, not medical device; do not select regulated-device categories). Caveat: if Play still requires an organization account after the declaration, fallback options are documented in `android/README.md`.
- [ ] Data safety form consistent with privacy policy; privacy policy URL required.
- [ ] Encryption at rest + in transit affirmed (SQLCipher + TLS) per health-app security requirements.
- [ ] No health data for ads/profiling; no age-restricted signals (satisfied by design).
- [ ] Health Connect not used in v1 → no `READ_HEALTH_DATA` permissions to justify.
- [ ] `SCHEDULE_EXACT_ALARM` declaration with reminder justification.
- [ ] Content rating questionnaire; target audience 13+.
- [ ] Store listing includes the medical disclaimer (common spec §7).

## 6. Network Endpoints (complete list — nothing else permitted)

| Purpose | Endpoint | Data sent |
|---|---|---|
| FR-4 | `world.openfoodfacts.org/api/v2/product/{barcode}` | barcode digits only |
| FR-15 | `world.openfoodfacts.org/cgi/search.pl` (product name search) | user-typed food name only |
| FR-10 | Curated feed URLs (CCF, FDA RSS, curated JSON) | none (GET) |
| FR-11 | Google Places/Maps SDK | Google-managed, transient location |

## 7. Testing & Release

- **Unit:** JUnit5 on HBI/SCCAI calculators (shared cross-platform test vectors), rules engine, key-wrap/restore logic, export/import round-trip.
- **UI:** Compose UI tests on quick-log ≤60 s flow, BiometricPrompt flow (with test hooks), FLAG_SECURE verification.
- **Device matrix:** Pixel 8 (AI path), Galaxy S24/S25 (Galaxy AI + One UI), Galaxy Z Flip (foldable), one budget device on fallback path, Android 9 minSdk emulator.
- **Migration tests:** Auto Backup restore to new device (PIN-recovery flow §2.1), Samsung Smart Switch transfer.
- **Beta:** Play internal testing → closed track with 10–20 patient testers.
- **CI:** GitHub Actions or Gradle-managed devices; Play App Signing.
- **Submission:** Play Console with health declaration; pre-launch report review; staged rollout 10% → 100%.
