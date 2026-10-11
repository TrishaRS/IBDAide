# IBD Aide — iOS Platform Specification

**Companion to:** `00-Product-Spec-Common.md` (FR-x references below). This document is self-sufficient for an iOS build team/tool when paired with the common spec.
**Spec v1.0 · July 2026**

---

## 1. Targets & Stack

| Item | Choice |
|---|---|
| Language | Swift 6, strict concurrency |
| UI | SwiftUI; MVVM + Observation framework |
| Min deployment | iOS 17.0 (broad device coverage) |
| AI feature gate | Foundation Models / Apple Intelligence features require iOS 26+ on Apple Intelligence-capable hardware (iPhone 15 Pro and later); graceful fallback below |
| Persistence | SwiftData (Core Data-backed), store file protected with `NSFileProtectionComplete` |
| Secrets | Keychain Services |
| Dependency policy | Zero third-party SDKs in v1 (all needs met by system frameworks) — simplifies privacy review |

## 2. Security & Privacy Architecture

### 2.1 Encryption at rest (NFR-1)
- SwiftData store + all app files created with `FileProtectionType.complete` — AES-encrypted by iOS Data Protection, keys held in Secure Enclave, inaccessible while device is locked.
- Photos captured for food scans stored in the protected container; scan photos deleted after inference by default (user toggle to keep).
- Exclude caches (`NewsItem`, `ScannedProduct` images) from backup via `isExcludedFromBackup`.

### 2.2 App lock — Face ID / Touch ID (FR-13)
- `LocalAuthentication` → `LAPolicy.deviceOwnerAuthentication` (biometric with device-passcode fallback). Optional app-level PIN stored as a salted hash in Keychain.
- Keychain items use `kSecAttrAccessibleWhenUnlocked` **without** `ThisDeviceOnly`, so the app-PIN survives encrypted-backup restore to a new iPhone (FR-14a). Detect restore-to-new-device (`kSecAttrAccessible` + device-ID check) and re-prompt for authentication setup.
- Auto-lock on `scenePhase != .active` past grace period; blur snapshot overlay so app switcher shows no health data.
- Required Info.plist string: `NSFaceIDUsageDescription`.

### 2.3 Backup & migration (FR-14)
- **(a)** App container participates in iCloud/Finder encrypted device backup by default → data survives phone upgrade/replacement. Note: Apple 5.1.3 forbids storing health data *in iCloud sync/CloudKit*; encrypted **device backups** are the sanctioned path and require no iCloud entitlement.
- **(b)** Manual export: serialize DB to the common JSON schema → encrypt with CryptoKit `AES.GCM`, key derived from user passphrase (PBKDF2, ≥600k iterations) → single `.ibdaide` file via `fileExporter`. Import validates schema version.

### 2.4 Privacy disclosures
- Privacy Nutrition Label: Health & Fitness data — "not collected" (never leaves device). Network calls (§6) declared as not linked to identity.
- No `NSUserTracking…`; no ATT prompt needed. Privacy manifest (`PrivacyInfo.xcprivacy`) declaring required-reason APIs (UserDefaults, file timestamps).

## 3. Feature Implementation Map

| FR | iOS implementation |
|---|---|
| FR-1/2/12 | SwiftUI forms + Swift Charts for trends; score calculators as a pure-Swift package with shared test vectors |
| FR-3 | Camera via `PhotosPicker`/`AVFoundation`; quick-add water widget-style buttons |
| FR-4 | `VisionKit` `DataScannerViewController` (barcode) → Open Food Facts REST (barcode only) → local rules engine + FR-5 model |
| FR-5 | **Primary:** Foundation Models framework (on-device Apple Foundation Model, multimodal prompt with dish photo + Vision framework tools) → structured ingredient list → rules engine. **Fallback (< iOS 26 / non-AI devices):** Vision `VNRecognizeTextRequest` OCR of ingredient labels → rules engine; dish-photo inference disabled with explanatory UI |
| FR-6 | Contacts-style detail views; address opens `MKMapItem` in Maps |
| FR-7 | Local notifications via `UserNotifications` (no push server); recurring infusion schedules via `UNCalendarNotificationTrigger`; colonoscopy-prep checklist as a task list |
| FR-8 | Notification actions ("Taken"/"Skip") via `UNNotificationCategory`; refill countdown logic in model layer |
| FR-9 | PDF via `ImageRenderer` (charts) + PDFKit composition → `ShareLink` (system share sheet; user sends via own Mail/Messages) |
| FR-10 | `BGAppRefreshTask` fetches curated feeds (JSON/RSS) ≤2×/day; local notification on new items. No push infrastructure, no server |
| FR-11 | `MKLocalSearch` "public restroom" near `CLLocationManager` location (`whenInUse` only); `NSLocationWhenInUseUsageDescription` |

## 4. UI Requirements (NFR-4/5/6)

- Tab bar: **Home** (today + quick log), **Trends**, **Scan**, **Care** (team/appointments/meds), **More** (report, news, toilet finder, settings).
- Quick log reachable in ≤2 taps post-unlock; BM log as a floating action on Home.
- Size classes + `ViewThatFits` so primary screens fit without scrolling on 6.1″+; support 4.7″ (SE) through 6.9″ (Pro Max); Dynamic Type up to accessibility sizes; VoiceOver labels on all controls; dark mode.
- SF Symbols, system colors + a calm custom accent; no medical-red alarm styling except true alerts.

## 5. App Store Compliance Checklist (Guideline 5.1.3 & related)

- [ ] No health data used for advertising/marketing/data mining (5.1.3(i)) — satisfied by design (no ads, no analytics).
- [ ] No personal health information stored in iCloud sync (5.1.3(ii)) — device backup only.
- [ ] No false data written to HealthKit — HealthKit not used in v1.
- [ ] Medical disclaimer (common spec §7) at onboarding and in App Store description.
- [ ] Privacy policy URL in App Store Connect.
- [ ] Privacy Nutrition Label + privacy manifest accurate.
- [ ] Age rating questionnaire → 12+; category: **Medical (primary)**, Health & Fitness (secondary). Medical-app review scrutiny is addressed: in-app citations (Sources screen, guideline 1.4.1), disclaimers, and no diagnosis/treatment claims.
- [ ] Camera/Face ID/location purpose strings present and specific.
- [ ] Export compliance: uses exempt standard encryption (`ITSAppUsesNonExemptEncryption = NO` with CryptoKit standard algorithms; file annual self-classification if required).

## 6. Network Endpoints (complete list — nothing else permitted)

| Purpose | Endpoint | Data sent |
|---|---|---|
| FR-4 | `world.openfoodfacts.org/api/v2/product/{barcode}` | barcode digits only |
| FR-15 | `world.openfoodfacts.org/cgi/search.pl` (product name search) | user-typed food name only |
| FR-10 | Curated feed URLs (CCF, FDA RSS, curated JSON) | none (GET) |
| FR-11 | Apple Maps via MapKit | Apple-managed, transient location |

## 7. Testing & Release

- **Unit:** XCTest on HBI/SCCAI calculators (shared cross-platform test vectors), food-rules engine, export/import round-trip, PBKDF2/AES vectors.
- **UI:** XCUITest on quick-log ≤60 s flow, app-lock behavior, share-sheet report.
- **Device matrix:** iPhone SE 3, 15, 15 Pro (AI path), 16/17 Pro Max; iOS 17 fallback path + iOS 26 AI path.
- **Migration test:** restore encrypted backup onto a second device; verify data + app-lock intact.
- **Beta:** TestFlight (internal → 10–20 patient external testers).
- **CI:** Xcode Cloud — build, test, TestFlight distribution.
- **Submission:** App Store Connect; expect health-app review scrutiny — include a reviewer demo note explaining local-only storage and the three network calls.
