import Foundation
import SwiftData

// MARK: - Enums (stored as raw values for SwiftData stability)

enum Diagnosis: String, Codable, CaseIterable, Identifiable {
    case crohns = "Crohn's disease"
    case ulcerativeColitis = "Ulcerative colitis"
    case ibdU = "IBD-unclassified"
    var id: String { rawValue }
}

enum ProviderRole: String, Codable, CaseIterable, Identifiable {
    case giDoctor = "GI doctor"
    case nurse = "Nurse"
    case infusionCenter = "IV / infusion center"
    case pharmacy = "Pharmacy"
    case other = "Other"
    var id: String { rawValue }
}

enum AppointmentType: String, Codable, CaseIterable, Identifiable {
    case officeVisit = "Office visit"
    case telehealth = "Telehealth"
    case infusion = "IV infusion"
    case labWork = "Lab work"
    case procedure = "Procedure / colonoscopy"
    var id: String { rawValue }
}

enum MedicationKind: String, Codable, CaseIterable, Identifiable {
    case oral = "Oral"
    case biologic = "Biologic (injection)"
    case infusion = "Biologic (IV infusion)"
    var id: String { rawValue }
}

enum DoseStatus: String, Codable { case taken, skipped }

// MARK: - Models (flat; cross-references by UUID to keep the schema simple and portable)

@Model
final class UserProfile {
    var id: UUID = UUID()
    var name: String = ""
    var diagnosisRaw: String = Diagnosis.crohns.rawValue
    var diagnosisDate: Date?
    var flareMode: Bool = false           // stricter food rules when true
    var onboarded: Bool = false
    var appLockEnabled: Bool = true
    var createdAt: Date = Date()

    var diagnosis: Diagnosis {
        get { Diagnosis(rawValue: diagnosisRaw) ?? .crohns }
        set { diagnosisRaw = newValue.rawValue }
    }

    init() {}
}

@Model
final class SymptomEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// 0–10 slider
    var abdominalPain: Int?
    /// 0–4 (very well … terrible), used by HBI/SCCAI general well-being
    var wellbeing: Int?
    /// 0–3
    var fatigue: Int?
    var nausea: Bool = false
    var jointPain: Bool = false
    var skinIssues: Bool = false
    var eyeIssues: Bool = false
    var mouthUlcers: Bool = false
    var weightLbs: Double?
    var sleepHours: Double?
    /// 0–4 (bad … great)
    var mood: Int?
    var notes: String = ""

    init(date: Date = Date()) { self.date = date }
}

@Model
final class BowelMovementEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    /// Bristol Stool Chart 1–7
    var bristol: Int = 4
    var blood: Bool = false
    /// 0 none, 1 hurry, 2 immediately, 3 incontinence
    var urgency: Int = 0
    var nighttime: Bool = false

    init(date: Date = Date(), bristol: Int = 4, blood: Bool = false, urgency: Int = 0) {
        self.date = date; self.bristol = bristol; self.blood = blood; self.urgency = urgency
    }
}

@Model
final class FoodEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var name: String = ""
    var caffeine: Bool = false
    var alcohol: Bool = false
    var notes: String = ""
    /// where it came from: manual | barcode | dish-scan
    var source: String = "manual"

    init(date: Date = Date(), name: String = "") { self.date = date; self.name = name }
}

@Model
final class TriggerFood {
    var id: UUID = UUID()
    var name: String = ""
    /// user | suggested
    var origin: String = "user"
    var createdAt: Date = Date()

    init(name: String, origin: String = "user") { self.name = name; self.origin = origin }
}

@Model
final class HydrationEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var glasses: Int = 1
    init(date: Date = Date(), glasses: Int = 1) { self.date = date; self.glasses = glasses }
}

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = ""
    var kindRaw: String = MedicationKind.oral.rawValue
    var prescriber: String = ""
    /// minutes from midnight for each daily dose time (empty for infusions)
    var scheduleTimes: [Int] = []
    /// for infusions: interval in weeks
    var intervalWeeks: Int?
    var pillsRemaining: Int?
    var refillDate: Date?
    var active: Bool = true
    var createdAt: Date = Date()

    var kind: MedicationKind {
        get { MedicationKind(rawValue: kindRaw) ?? .oral }
        set { kindRaw = newValue.rawValue }
    }

    init(name: String = "") { self.name = name }
}

@Model
final class DoseEvent {
    var id: UUID = UUID()
    var medicationID: UUID = UUID()
    var scheduledAt: Date = Date()
    var recordedAt: Date = Date()
    var statusRaw: String = DoseStatus.taken.rawValue

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    init(medicationID: UUID, scheduledAt: Date, status: DoseStatus) {
        self.medicationID = medicationID
        self.scheduledAt = scheduledAt
        self.statusRaw = status.rawValue
    }
}

@Model
final class Provider {
    var id: UUID = UUID()
    var name: String = ""
    var roleRaw: String = ProviderRole.giDoctor.rawValue
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var portalURL: String = ""
    var notes: String = ""

    var role: ProviderRole {
        get { ProviderRole(rawValue: roleRaw) ?? .other }
        set { roleRaw = newValue.rawValue }
    }

    init(name: String = "") { self.name = name }
}

@Model
final class Appointment {
    var id: UUID = UUID()
    var typeRaw: String = AppointmentType.officeVisit.rawValue
    var date: Date = Date()
    var providerID: UUID?
    var locationNote: String = ""
    /// recurring interval in weeks (e.g. 8 for infusions); nil = one-off
    var recurringWeeks: Int?
    /// reminder offsets in hours before the appointment
    var reminderOffsetsHours: [Int] = [168, 24, 2]
    var preVisitNotes: String = ""
    var postVisitNotes: String = ""
    /// colonoscopy prep checklist items marked done
    var prepDone: [String] = []

    var type: AppointmentType {
        get { AppointmentType(rawValue: typeRaw) ?? .officeVisit }
        set { typeRaw = newValue.rawValue }
    }

    static let prepChecklist = [
        "Confirm prep prescription picked up",
        "Start low-fiber diet (2 days before)",
        "Clear liquids only (1 day before)",
        "Begin prep drink as instructed",
        "Arrange ride home",
        "Nothing by mouth after midnight",
    ]

    init(type: AppointmentType = .officeVisit, date: Date = Date()) {
        self.typeRaw = type.rawValue; self.date = date
    }
}

@Model
final class VisitQuestion {
    var id: UUID = UUID()
    var text: String = ""
    var createdAt: Date = Date()
    var appointmentID: UUID?
    var asked: Bool = false

    init(text: String) { self.text = text }
}

@Model
final class QoLCheckin {
    var id: UUID = UUID()
    var date: Date = Date()
    /// 8 answers, each 0–4 (adapted from IBD-Control-8; higher = better control)
    var answers: [Int] = []
    var total: Int = 0

    init(date: Date = Date(), answers: [Int]) {
        self.date = date; self.answers = answers; self.total = answers.reduce(0, +)
    }

    static let questions = [
        "I have felt in control of my IBD",
        "My IBD has NOT interfered with daily activities",
        "I have NOT missed planned activities because of IBD",
        "I have slept well",
        "My energy levels have been good",
        "I have felt free of significant pain or discomfort",
        "I have NOT felt anxious or depressed about my IBD",
        "I believe my current treatment is working",
    ]
}

/// FR-16: a recommendation imported from the user's own nutritionist/dietitian.
/// verdictRaw: "ok" (explicitly allowed), "caution", or "avoid".
@Model
final class NutritionistRule {
    var id: UUID = UUID()
    var foodName: String = ""
    var verdictRaw: String = "caution"
    var note: String = ""
    var createdAt: Date = Date()

    init(foodName: String, verdictRaw: String, note: String = "") {
        self.foodName = foodName
        self.verdictRaw = verdictRaw
        self.note = note
    }
}

@Model
final class ScannedProduct {
    var id: UUID = UUID()
    var barcode: String = ""
    var name: String = ""
    var brand: String = ""
    var ingredientsText: String = ""
    var fetchedAt: Date = Date()

    init(barcode: String, name: String, brand: String, ingredientsText: String) {
        self.barcode = barcode; self.name = name; self.brand = brand; self.ingredientsText = ingredientsText
    }
}

@Model
final class NewsItem {
    var id: UUID = UUID()
    var guid: String = ""
    var title: String = ""
    var source: String = ""
    var link: String = ""
    var publishedAt: Date = Date()
    var summary: String = ""
    var isRead: Bool = false

    init(guid: String, title: String, source: String, link: String, publishedAt: Date, summary: String) {
        self.guid = guid; self.title = title; self.source = source
        self.link = link; self.publishedAt = publishedAt; self.summary = summary
    }
}

// MARK: - Schema helper

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self, SymptomEntry.self, BowelMovementEntry.self, FoodEntry.self,
        TriggerFood.self, HydrationEntry.self, Medication.self, DoseEvent.self,
        Provider.self, Appointment.self, VisitQuestion.self, QoLCheckin.self,
        ScannedProduct.self, NewsItem.self, NutritionistRule.self,
    ]
}
