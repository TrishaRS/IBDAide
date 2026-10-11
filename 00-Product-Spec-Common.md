# IBD Aide — Product Specification (Common)

**Working name:** IBD Aide (fallback: IBD Harbor — verify availability in App Store Connect & Play Console before submission)
**Version:** Spec v1.0 · July 2026
**Platforms:** iOS (native SwiftUI) and Android (native Kotlin/Compose) — see platform specs `01-iOS-Spec.md` and `02-Android-Spec.md`
**Price:** Free. No ads. No subscriptions. No sale or sharing of user data.

---

## 1. Vision

A private, fast, clinically-grounded companion for people with Inflammatory Bowel Disease (Crohn's disease, ulcerative colitis, IBD-unclassified). All health data stays on the user's device, encrypted, behind biometrics — while still surviving phone upgrades.

**Design north star:** logging a symptom takes under 60 seconds. Research shows users abandon health trackers within 2 weeks if logging is slow.

## 2. Audience & Condition Scope

- Public release for all IBD patients (US, English, at launch).
- Supported diagnoses selected at onboarding: **Crohn's disease**, **ulcerative colitis**, **IBD-unclassified (IBD-U)**.
- Diagnosis drives which clinical score is computed: Crohn's → Modified Harvey-Bradshaw Index (HBI); UC → Simple Clinical Colitis Activity Index (SCCAI); IBD-U → symptom trends only.

## 3. Functional Requirements

### FR-1 Symptom Tracking (quick log)
- One-tap logging from home screen: bowel movement (Bristol Stool Chart 1–7), blood present, urgency, abdominal pain (0–10), fatigue, nausea, joint pain, extra-intestinal symptoms, weight, sleep hours, mood.
- Auto-computes HBI (Crohn's) or SCCAI (UC) from logged entries; shows score band (remission / mild / moderate / severe) with the disclaimer in §7.
- Every field optional; partial logs allowed; entries editable and backdatable.
- Acceptance: full symptom log completable in ≤60 s; quick BM log in ≤10 s.

### FR-2 Flare Insights & Trends
- Charts: symptom frequency, score trend, weight, sleep — daily/weekly/monthly/yearly.
- Flare detection heuristic: sustained score elevation over user baseline triggers a gentle "possible flare — consider contacting your care team" prompt (never a diagnosis).
- Trigger correlation: surfaces foods logged within 4–48 h before symptom spikes.

### FR-3 Food & Hydration Diary
- Log meals (free text, photo, or scan via FR-4/FR-5), water intake (quick +1 glass), caffeine/alcohol flags.
- Personal trigger list: user marks foods as triggers; app also suggests trigger candidates from FR-2 correlation.

### FR-4 Barcode Scan — Packaged Food Safety
- Camera scans barcode → ingredient list fetched from **Open Food Facts** (free, open database) → on-device AI evaluates against (a) general IBD dietary guidance (e.g., high-residue, high-fat, sorbitol, carrageenan flags; flare-mode vs remission-mode strictness) and (b) the user's personal trigger list.
- Result: Green / Caution / Avoid, with the specific flagged ingredients and why.
- Only the barcode number is sent over the network — never any user or health data.
- Offline fallback: cached previously-scanned products; otherwise prompt manual ingredient photo (FR-5).

### FR-5 Dish Photo Scan — Prepared Food Safety
- Camera photo of a dish or ingredient label → **on-device AI** (Apple Intelligence / Gemini Nano — see platform specs) infers likely ingredients → same Green/Caution/Avoid evaluation as FR-4.
- Explicit uncertainty language: "likely contains…" — inference, not fact.
- Runs fully on device; photo never leaves the phone. Devices without on-device AI fall back to OCR of ingredient labels + rule-based matching.

### FR-6 Care Team Directory
- Store providers and facilities: name, role (GI doctor, nurse, IV/infusion center, pharmacy), phone, email, address (with map link), notes, portal URL.

### FR-7 Appointments — Doctor Visits & IV Infusions
- Appointment types: office visit, telehealth, IV/infusion, lab work, procedure (colonoscopy prep checklist included).
- Linked to a care-team entry; recurring infusion schedules (e.g., every 8 weeks) supported.
- Local notification reminders: configurable (1 week / 1 day / 2 h before).
- **Pre-visit question builder:** running list of questions to ask, attachable to an appointment; questions can be added any time ("capture it when you think of it"); shown prominently on appointment day and included in the FR-9 report.
- Post-visit notes field.

### FR-8 Medication Tracking
- Oral meds, biologics, and IV infusions: name, dose, schedule, prescriber.
- Adherence reminders (local notifications), taken/skipped log, streaks.
- Refill alerts: user sets pills-remaining or refill date → reminder before runout.
- Infusion doses auto-link to FR-7 IV appointments.

### FR-9 Doctor Report — PDF Export & Share
- Generates a clean PDF: date range, symptom summary, score trend chart, medication adherence, food triggers, appointment questions.
- Shared via the OS share sheet (user's own Mail/Messages/etc.). **The app never transmits health data itself** — this keeps it out of HIPAA-covered transmission scope.

### FR-10 Research & Treatment News
- In-app feed of IBD treatment advancements from curated authoritative sources (Crohn's & Colitis Foundation, FDA drug approvals, PubMed/clinical trial summaries).
- Fetched via periodic background refresh; optional local notification for new items. No account, no server-side profile — feed requests carry no user identifiers.
- Every item carries the §7 disclaimer.

### FR-11 Toilet Finder
- Map of nearby public restrooms using device location + platform map search (see platform specs). Location used transiently, never stored or transmitted with health data.

### FR-12 Quality-of-Life Check-ins
- Short validated questionnaire (IBD-Control 8-item) offered every 2 weeks; trend shown alongside symptom scores; included in FR-9 report.

### FR-13 App Lock
- Biometric unlock (Face ID / Touch ID / fingerprint / face) with device-passcode fallback, plus an app-level PIN option.
- Auto-locks on backgrounding (configurable grace period, default immediate). Lock screen shows no health data; notification content is generic ("You have a reminder").

### FR-15 Food Safety Knowledge Base & Lookup
- Ships a built-in, offline inventory compiled from authoritative sources — Crohn's & Colitis Foundation "What Should I Eat?" and IOIBD 2020 dietary guidance: flagged ingredients/additives (with per-item reason + source), a dish inventory of common meals with typical ingredients, and a "generally well tolerated" list.
- FR-4/FR-5 verdicts are computed against this knowledge base + personal triggers; results cite the source per finding and list recognized safe foods.
- **Lookup:** user can search any dish, food, or ingredient against the knowledge base, and optionally check packaged products via Open Food Facts name search (only the typed term is sent). Source links displayed in-app.

### FR-16 Nutritionist Plan Import
- User can import their own nutritionist/dietitian's recommendations (CSV or JSON file, or manual entry): food/ingredient + Allowed / Caution / Avoid + optional note.
- Plan entries apply to all food scans and lookups with priority over the built-in CCF/IOIBD guidance (personal triggers still rank highest); an "Allowed" entry suppresses general-guidance flags for that food and shows as a green confirmation attributed to the nutritionist.
- Stored locally like all data; included in encrypted export (schema-versioned, backward compatible).

### FR-14 Backup & Device Migration (both models)
- **(a) Platform backup:** app data participates in encrypted device backups (iCloud / Android Auto Backup) so data survives phone upgrades and replacements automatically.
- **(b) Manual encrypted export/import:** user-initiated export of the full database to a single file, AES-256-GCM encrypted with a user passphrase; importable on either… the same platform (cross-platform import is a v1.1 goal via a common JSON schema).

## 4. Non-Functional Requirements

| # | Requirement |
|---|---|
| NFR-1 | All health data stored locally, encrypted at rest (platform specifics in platform docs). No health data ever sent to any server. |
| NFR-2 | Permitted network calls (no PHI): Open Food Facts barcode lookup, news feed fetch, map/restroom search. Each documented in privacy disclosures. |
| NFR-3 | No third-party analytics, ad, or tracking SDKs. Crash reporting: platform-native only (opt-in), scrubbed of health data. |
| NFR-4 | UI: clean, modern, professional. Adaptive layouts for all current phone sizes (4.7″–6.9″, foldables on Android); key screens fit without scrolling on ≥6.1″ displays. |
| NFR-5 | Accessibility: dynamic type, screen readers (VoiceOver/TalkBack), ≥4.5:1 contrast, 44 pt/48 dp touch targets. |
| NFR-6 | Performance: cold start <2 s on mid-range devices; quick log reachable in ≤2 taps from launch (post-unlock). |
| NFR-7 | Works fully offline except FR-4 lookup, FR-10 feed, FR-11 map. |

## 5. Data Model (entities)

`UserProfile` (diagnosis, dx date, flare/remission mode) · `SymptomEntry` · `BowelMovement` · `FoodEntry` · `TriggerFood` · `HydrationEntry` · `Medication` · `DoseEvent` · `Provider` · `Facility` · `Appointment` · `Question` · `QoLCheckin` · `ScannedProduct` (cache) · `NewsItem` (cache)

All timestamps in UTC with local-tz display. Common JSON export schema shared across platforms (enables future cross-platform migration).

## 6. Compliance (common)

- **Not a medical device.** App is positioned as a wellness/tracking tool: it never diagnoses, treats, or recommends therapy changes. This keeps it outside FDA SaMD and Google Play "Medical Device" labeling. All score outputs framed as "for discussion with your care team."
- No HIPAA covered-entity role: app is patient-held, no provider transmission, no cloud PHI.
- Store-specific obligations (Apple 5.1.3, Google Play Health Apps Declaration, org account) in platform specs.
- Onboarding consent screen + persistent disclaimer (§7). Privacy policy URL required by both stores.
- Age rating: 12+/equivalent; no children's targeting.

## 7. Standard Disclaimer (verbatim, shown at onboarding and on scores/food results/news)

> IBD Aide is a tracking tool, not a medical device. It does not provide medical advice, diagnosis, or treatment. Food safety results are informational estimates and can be wrong or incomplete. Always consult your healthcare team before making changes to diet, medication, or treatment. If you have severe symptoms, seek medical care immediately.

## 8. Roadmap

- **v1.0:** Everything above.
- **v1.1:** Cross-platform encrypted import (iOS ↔ Android), Spanish localization.
- **v1.2:** Apple Watch app, home-screen widgets, HealthKit / Health Connect integration.
- **Later:** caregiver read-only sharing, additional languages, tablet layouts.

## 9. Success Metrics (privacy-safe, on-device only unless user opts into aggregate)

- D14 retention of logging (the 2-week cliff), median time-to-log, % of users generating ≥1 doctor report, crash-free rate ≥99.5%.

## 10. Delivery Lifecycle (both platforms)

1. **Plan** — this spec; wireframes for the 6 core screens (Home/quick-log, Trends, Scan, Care Team & Appointments, Meds, Report).
2. **Design** — high-fidelity mockups; design tokens shared across platforms (color, type scale, spacing) for brand consistency with platform-native components.
3. **Build** — vertical slices in order: data layer + encryption + app lock → FR-1/FR-2 → FR-7/FR-6/FR-8 → FR-9 → FR-4/FR-5 → FR-3/FR-11/FR-12 → FR-10 → FR-14.
4. **Test** — unit tests on score calculators and food-rules engine (shared test vectors across platforms), UI tests on quick-log flow, restore-from-backup test on a second device, accessibility audit.
5. **Beta** — TestFlight / Play internal testing with 10–20 IBD patients; iterate on logging speed.
6. **Submit** — store checklists in platform specs.
7. **Post-launch** — monitor crash rates, review feedback, ship v1.1.
