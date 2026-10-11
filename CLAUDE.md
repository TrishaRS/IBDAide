# IBD Aide — repo guide for Claude

Free, privacy-first IBD (Crohn's/UC) tracker. Creator: Trisha Samanpure. All health
data on-device, encrypted; no accounts/analytics/ads. Not a medical device —
informational only, with in-app citations (CCF, IOIBD, HBI/SCCAI papers).

## Layout
- `00–06 *.md` — specs (common / iOS / Android), listing copy, submission + publish steps.
- `ios/` — native SwiftUI app (Xcode 16+ synchronized-folder project; min iOS 17).
  Core logic in `ios/IBDAide/Core/` (scoring, food knowledge base + rules engine,
  export crypto, PDF). Reference tests in `ios/Tests/` (add a test target to run).
- `android/` — native Kotlin/Compose app (min SDK 28). Mirrors iOS feature-for-feature
  except FR-16 nutritionist import (TODO) and deliberate deviations in `android/README.md`.
- `website/` — privacy policy + support pages (host before store submission).
- `branding/`, `appstore-screenshots/`, `demo-video/` — icon SVG sources and marketing assets.

## Invariants — do not break
- Health data never leaves the device; the ONLY network calls are Open Food Facts
  (barcode digits / typed food name), news feeds, and map search. No new endpoints
  without updating specs §6 + privacy policy + store privacy labels.
- Scores are *modified, patient-reported* HBI/SCCAI adaptations — keep "not a diagnosis"
  framing and the shared cross-platform test vectors (iOS `ScoringTests` = Android `ScoringTest`).
- Rule precedence in food evaluation: personal triggers > nutritionist plan (FR-16) >
  built-in CCF/IOIBD rules. Keep iOS and Android knowledge bases identical.
- Encrypted export: salt(16)+nonce(12)+AES-256-GCM, PBKDF2-SHA256 600k; JSON field
  names shared across platforms; new fields must be optional for backward compat.
- WCAG AA: text on tinted fills uses the dark "text" color variants (Theme.swift / Theme.kt),
  never the decorative fill colors.
- Store positioning: iOS = Medical category; Android = Lifestyle (personal account
  constraint — see android/README.md). App text never claims diagnosis/treatment.
- Sample data persona is "Alex" — never imply the creator is a patient.

## Gotchas
- The repo may live on an exFAT external SSD: `._*` AppleDouble files appear everywhere
  (gitignored); Gradle builds fail on the SSD — copy `android/` to the internal disk to build.
- `ios/IBDAide.xcodeproj` uses Xcode 16 synchronized folders: new Swift files under
  `ios/IBDAide/` are picked up automatically; no pbxproj edits needed.
