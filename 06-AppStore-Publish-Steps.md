# IBD Aide — Publish to the App Store (v1.1, Medical category)

End-to-end steps from Xcode to a live App Store release. The App Store's healthcare
category is named **Medical** — set as the primary category below.
Version 1.1 adds: nutritionist plan import (FR-16), accessibility contrast update,
citations screens, and the news/PDF fixes.

## 1. Xcode — verify & archive

1. Open `ios/IBDAide.xcodeproj` in the latest Xcode (26 or newer; build against the latest iOS SDK it ships).
2. **Cmd+B** — must compile with zero errors.
3. Quick pass on a simulator (**Cmd+R**): More ▸ Nutritionist plan (import a sample CSV), Scan verdicts, Sources links, quick-log buttons readable.
4. Target **IBDAide ▸ General**: Version `1.1`, Build `1` (every upload needs a unique build number; bump Build for re-uploads).
5. Signing & Capabilities: Team selected; bundle ID matches the registered App ID; Data Protection (Complete) capability from the App ID applies automatically.
6. Device selector → **Any iOS Device (arm64)** → **Product ▸ Archive**.

## 2. Upload

7. Organizer → select archive → **Distribute App ▸ App Store Connect ▸ Upload** (accept defaults).
8. Wait for the processing email (5–30 min). No export-compliance prompt should appear (`ITSAppUsesNonExemptEncryption = NO`); if asked, answer "None of the algorithms mentioned above."
9. Optional but recommended: install the processed build from **TestFlight** on a real iPhone and spend ten minutes in it.

## 3. App Store Connect — category & version

10. appstoreconnect.apple.com ▸ My Apps ▸ IBD Aide.
11. **App Information ▸ Category**: Primary **Medical**, Secondary **Health & Fitness** ▸ Save. (Takes effect when this version is approved. Medical-category scrutiny is covered: in-app citations, disclaimers, no treatment claims.)
12. If v1.0 is live: click **＋** next to "iOS App" → version `1.1`. If v1.0 is still in review/rejected: reuse the 1.0 page and just swap the build (then keep Version 1.0, Build N+1 in step 4 instead).
13. **What's New** (for 1.1):
    > • Import your own nutritionist's recommendations (CSV/JSON or manual) — they now guide every food scan
    > • Medical sources & citations screen
    > • Improved color contrast and dark-mode readability
    > • News articles open in-app; doctor-report PDF improvements
14. Build section → **＋** → select the processed build.
15. Verify App Privacy still says **Data Not Collected**, and the privacy policy + support URLs are set (host `website/` first if not yet done).

## 4. Submit & release

16. **Save → Add for Review → Submit to App Review.**
17. If responding to a prior rejection, reply in the App Review message thread describing the citation changes before submitting.
18. Typical review: 1–3 days. On approval with manual release: press **Release This Version**.

## Pre-flight checklist

- [ ] Build compiles clean on latest SDK; smoke-tested on device/simulator
- [ ] Version/build bumped; archive uploaded and processed
- [ ] Category set: Medical (primary) / Health & Fitness (secondary)
- [ ] Privacy policy + support pages hosted; URLs in App Store Connect
- [ ] Real screenshots captured from the running app (replace design mockups)
- [ ] Dietitian review applied to `FoodKnowledgeBase.swift` (rule table workbook)
- [ ] Curated news feeds replacing the Google News placeholder
- [ ] Reviewer notes included (local-only storage; three network calls; no sign-in)
