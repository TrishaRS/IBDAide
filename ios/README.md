# IBD Aide — iOS App (v1.0 source)

Native SwiftUI implementation of `01-iOS-Spec.md` + `00-Product-Spec-Common.md`.

## Build & run

1. **Requirements:** Mac with **Xcode 16 or newer** (project uses synchronized folder groups). iOS 17.0+ deployment target.
2. Open `IBDAide.xcodeproj`.
3. Select the `IBDAide` target ▸ Signing & Capabilities ▸ choose your **Team** (bundle ID `com.ibdaide.app` — change to your own).
4. Pick a simulator or device and **Run**.

Camera barcode scanning and Face ID need a physical iPhone; the Scan tab automatically falls back to manual barcode entry and photo picking in the Simulator.

## What's implemented (spec mapping)

| FR | Status | Where |
|---|---|---|
| FR-1 Symptom quick log (Bristol ≤10 s, full ≤60 s) | ✅ | `Features/Home/` |
| FR-2 Trends, flare heuristic, trigger correlation | ✅ | `Features/Trends/`, `Core/Analytics.swift` |
| FR-3 Food & hydration diary | ✅ | Home quick-log + Scan "Log as meal" |
| FR-4 Barcode → Open Food Facts → rules engine | ✅ | `Features/Scan/`, `Core/OpenFoodFactsClient.swift`, `Core/FoodRulesEngine.swift` |
| FR-15 Built-in food knowledge base (CCF + IOIBD sourced) + lookup | ✅ | `Core/FoodKnowledgeBase.swift`, `Features/Scan/FoodLookupView.swift` |
| FR-16 Nutritionist plan import (CSV/JSON/manual, overrides general guidance) | ✅ | `Features/More/NutritionistPlanView.swift`, `Core/FoodRulesEngine.swift` — Android parity: TODO |
| FR-5 Dish/label photo → on-device AI | ✅ | `Core/IngredientInference.swift` — Vision OCR + image classification on all devices; Apple Intelligence (Foundation Models) refinement compiles automatically with an iOS 26 SDK |
| FR-6 Care team directory | ✅ | `Features/Care/` |
| FR-7 Appointments, reminders, question builder, colonoscopy prep | ✅ | `Features/Care/` |
| FR-8 Meds, adherence, refills, notification actions | ✅ | `Features/Meds/`, `Core/NotificationManager.swift` |
| FR-9 PDF doctor report → share sheet | ✅ | `Features/More/ReportView.swift`, `Core/PDFReportBuilder.swift` |
| FR-10 Treatment news | ✅ (on-demand fetch) | `Features/More/NewsView.swift`, `Core/NewsFeedService.swift` |
| FR-11 Restroom finder | ✅ | `Features/More/ToiletFinderView.swift` |
| FR-12 QoL check-in | ✅ | `Features/More/QoLCheckinView.swift` |
| FR-13 Face ID app lock | ✅ | `Core/AppLockManager.swift` |
| FR-14a Encrypted device backup survival | ✅ (default container, no iCloud sync) | — |
| FR-14b Manual AES-256-GCM export/import | ✅ | `Core/ExportManager.swift`, Settings |

Clinical scores are **modified, patient-reported** HBI / SCCAI adaptations (`Core/Scoring.swift`) — labeled as informational throughout the UI.

## Before App Store submission (deliberately left for you)

- ~~App icon~~ — done: `Assets.xcassets/AppIcon` (source SVGs + alternates in `../branding/`).
- **Unit tests** — add a Unit Testing Bundle target and drop in `Tests/ScoringTests.swift` (instructions at top of file). Same vectors should power the Android JUnit tests.
- **News sources** — `NewsFeedService.sources` ships with FDA press RSS + a Google News query placeholder. Replace with your curated feed list.
- **Background news refresh** — v1 fetches on demand. To add `BGAppRefreshTask` you'll need a real Info.plist with `BGTaskSchedulerPermittedTaskIdentifiers` (the project currently uses a generated one).
- **Food rules review** — have a GI dietitian review/extend `FoodRulesEngine.rules`.
- **Export compliance** — set `ITSAppUsesNonExemptEncryption = NO` in App Store Connect (standard-algorithm exemption).
- **Privacy** — fill the Privacy Nutrition Label ("data not collected"), add privacy policy URL, review the checklist in `01-iOS-Spec.md` §5.
- **Dish-photo AI** — the Foundation Models call in `IngredientInference.swift` activates when built with an SDK that has `FoundationModels` (Xcode 26+) and runs only on Apple Intelligence-capable devices; verify the API surface against the final SDK.

## Privacy model (matches spec)

Health data: on-device only, encrypted at rest (`NSFileProtectionComplete`), behind Face ID, generic notification text, no analytics/ads/accounts. Network calls: Open Food Facts (barcode digits only), news feeds (no identifiers), MapKit search. Backups: encrypted device backups + passphrase-protected manual export (PBKDF2 600k ▸ AES-256-GCM).
