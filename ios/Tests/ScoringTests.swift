// Reference unit tests for the score calculators and food rules engine.
// NOT part of the app target. To use:
//   1. In Xcode: File ▸ New ▸ Target ▸ Unit Testing Bundle ("IBDAideTests")
//   2. Add this file to that target, set "IBDAide" as the host app,
//      and enable "Allow testing Host Application APIs".
// These vectors are the shared cross-platform test vectors (spec §Testing) —
// reuse the same inputs/outputs in the Android JUnit tests.

import XCTest
@testable import IBD_Aide

final class ScoringTests: XCTestCase {

    // MARK: Modified HBI vectors

    func testHBIAllQuiet() {
        let snap = DailySnapshot(abdominalPain: 0, wellbeing: 0, liquidStools: 0, totalStools: 1,
                                 nightStools: 0, maxUrgency: 0, bloodFraction: 0,
                                 nausea: false, jointPain: false, skinIssues: false,
                                 eyeIssues: false, mouthUlcers: false)
        XCTAssertEqual(Scoring.modifiedHBI(snap), 0)
        XCTAssertEqual(Scoring.hbiBand(0), .remission)
    }

    func testHBIModerateFlare() {
        // wellbeing 3 + pain 7→3 + 4 liquid stools + joint pain 1 + nausea 1 = 12 → moderate
        let snap = DailySnapshot(abdominalPain: 7, wellbeing: 3, liquidStools: 4, totalStools: 6,
                                 nightStools: 1, maxUrgency: 2, bloodFraction: 0.5,
                                 nausea: true, jointPain: true, skinIssues: false,
                                 eyeIssues: false, mouthUlcers: false)
        XCTAssertEqual(Scoring.modifiedHBI(snap), 12)
        XCTAssertEqual(Scoring.hbiBand(12), .moderate)
    }

    func testHBINoData() {
        let snap = DailySnapshot(abdominalPain: nil, wellbeing: nil, liquidStools: 0, totalStools: 0,
                                 nightStools: 0, maxUrgency: 0, bloodFraction: 0,
                                 nausea: false, jointPain: false, skinIssues: false,
                                 eyeIssues: false, mouthUlcers: false)
        XCTAssertNil(Scoring.modifiedHBI(snap))
        XCTAssertEqual(Scoring.hbiBand(nil), .unknown)
    }

    // MARK: Modified SCCAI vectors

    func testSCCAIRemission() {
        // 2 day stools (0) + 0 night (0) + urgency 0 + blood 0 + wellbeing 1 = 1 → remission
        let snap = DailySnapshot(abdominalPain: 1, wellbeing: 1, liquidStools: 0, totalStools: 2,
                                 nightStools: 0, maxUrgency: 0, bloodFraction: 0,
                                 nausea: false, jointPain: false, skinIssues: false,
                                 eyeIssues: false, mouthUlcers: false)
        XCTAssertEqual(Scoring.modifiedSCCAI(snap), 1)
        XCTAssertEqual(Scoring.sccaiBand(1), .remission)
    }

    func testSCCAIActive() {
        // 8 day stools (2) + 2 night (1) + urgency 2 + blood 0.5→2 + wellbeing 3 + joint 1 = 11 → moderate
        let snap = DailySnapshot(abdominalPain: 5, wellbeing: 3, liquidStools: 6, totalStools: 10,
                                 nightStools: 2, maxUrgency: 2, bloodFraction: 0.5,
                                 nausea: false, jointPain: true, skinIssues: false,
                                 eyeIssues: false, mouthUlcers: false)
        XCTAssertEqual(Scoring.modifiedSCCAI(snap), 11)
        XCTAssertEqual(Scoring.sccaiBand(11), .moderate)
    }

    // MARK: Pain mapping

    func testPainMapping() {
        XCTAssertEqual(Scoring.mapPain(nil), 0)
        XCTAssertEqual(Scoring.mapPain(0), 0)
        XCTAssertEqual(Scoring.mapPain(2), 1)
        XCTAssertEqual(Scoring.mapPain(5), 2)
        XCTAssertEqual(Scoring.mapPain(10), 3)
    }

    // MARK: Food rules engine

    func testPersonalTriggerAlwaysAvoid() {
        let eval = FoodRulesEngine.evaluate(ingredientsText: "oats, honey, almonds, salt",
                                            personalTriggers: ["almonds"], flareMode: false)
        XCTAssertEqual(eval.overall, .avoid)
        XCTAssertTrue(eval.findings.contains { $0.isPersonalTrigger })
    }

    func testFlareModeEscalates() {
        let remission = FoodRulesEngine.evaluate(ingredientsText: "chicory root fiber, water",
                                                 personalTriggers: [], flareMode: false)
        let flare = FoodRulesEngine.evaluate(ingredientsText: "chicory root fiber, water",
                                             personalTriggers: [], flareMode: true)
        XCTAssertEqual(remission.overall, .caution)
        XCTAssertEqual(flare.overall, .avoid)
    }

    func testCleanIngredientsGreen() {
        let eval = FoodRulesEngine.evaluate(ingredientsText: "water, white rice, chicken breast, salt",
                                            personalTriggers: [], flareMode: true)
        XCTAssertEqual(eval.overall, .green)
        XCTAssertTrue(eval.findings.isEmpty)
    }

    // MARK: Food knowledge base

    func testDishInventoryFlagsFriedChickenInFlare() {
        let eval = FoodRulesEngine.evaluateDish(labels: ["fried chicken"], inferredIngredients: [],
                                                personalTriggers: [], flareMode: true)
        XCTAssertEqual(eval.dishName, "Fried chicken")
        XCTAssertEqual(eval.overall, .avoid) // fried → avoid during flares (CCF)
    }

    func testSafeFoodsReported() {
        let eval = FoodRulesEngine.evaluate(ingredientsText: "white rice, grilled chicken, banana",
                                            personalTriggers: [], flareMode: true)
        XCTAssertEqual(eval.overall, .green)
        XCTAssertFalse(eval.safeFindings.isEmpty)
    }

    func testIOIBDAdditiveFlagged() {
        let eval = FoodRulesEngine.evaluate(ingredientsText: "water, maltodextrin, polysorbate 80",
                                            personalTriggers: [], flareMode: false)
        XCTAssertTrue(eval.findings.contains { $0.source == .ioibd })
        XCTAssertEqual(eval.overall, .caution)
    }

    func testKBLookupFindsDishAndSafeFood() {
        let dishHits = FoodKnowledgeBase.search("pizza", personalTriggers: [], flareMode: false)
        XCTAssertFalse(dishHits.isEmpty)
        let safeHits = FoodKnowledgeBase.search("banana", personalTriggers: [], flareMode: false)
        XCTAssertFalse(safeHits.isEmpty)
    }

    // MARK: Export crypto round-trip

    func testExportEncryptDecryptRoundTrip() throws {
        var env = ExportEnvelope()
        env.profile = .init(name: "Test", diagnosis: Diagnosis.crohns.rawValue, diagnosisDate: nil, flareMode: false)
        let data = try ExportManager.encrypt(env, passphrase: "correct horse battery")
        let restored = try ExportManager.decrypt(data, passphrase: "correct horse battery")
        XCTAssertEqual(restored.profile?.name, "Test")
        XCTAssertThrowsError(try ExportManager.decrypt(data, passphrase: "wrong"))
    }
}
