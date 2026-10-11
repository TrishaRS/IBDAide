import Foundation
import Security
import CryptoKit
import CommonCrypto
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// FR-14b: manual encrypted export/import.
/// File layout: [16-byte salt][AES-GCM combined (nonce+ciphertext+tag)]
/// Key: PBKDF2-HMAC-SHA256, 600,000 iterations → 256-bit AES key.
/// JSON payload uses the common cross-platform schema (spec §5).

struct ExportEnvelope: Codable {
    var schemaVersion = 1
    var app = "IBD Aide iOS"
    var exportedAt = Date()

    struct ProfileDTO: Codable { var name: String; var diagnosis: String; var diagnosisDate: Date?; var flareMode: Bool }
    struct SymptomDTO: Codable {
        var date: Date; var abdominalPain: Int?; var wellbeing: Int?; var fatigue: Int?
        var nausea: Bool; var jointPain: Bool; var skinIssues: Bool; var eyeIssues: Bool; var mouthUlcers: Bool
        var weightLbs: Double?; var sleepHours: Double?; var mood: Int?; var notes: String
    }
    struct BMDTO: Codable { var date: Date; var bristol: Int; var blood: Bool; var urgency: Int; var nighttime: Bool }
    struct FoodDTO: Codable { var date: Date; var name: String; var caffeine: Bool; var alcohol: Bool; var source: String }
    struct TriggerDTO: Codable { var name: String; var origin: String }
    struct HydrationDTO: Codable { var date: Date; var glasses: Int }
    struct MedDTO: Codable {
        var id: UUID; var name: String; var dose: String; var kind: String; var prescriber: String
        var scheduleTimes: [Int]; var intervalWeeks: Int?; var pillsRemaining: Int?; var refillDate: Date?; var active: Bool
    }
    struct DoseDTO: Codable { var medicationID: UUID; var scheduledAt: Date; var recordedAt: Date; var status: String }
    struct ProviderDTO: Codable {
        var id: UUID; var name: String; var role: String; var phone: String; var email: String
        var address: String; var portalURL: String; var notes: String
    }
    struct ApptDTO: Codable {
        var type: String; var date: Date; var providerID: UUID?; var locationNote: String
        var recurringWeeks: Int?; var reminderOffsetsHours: [Int]; var preVisitNotes: String
        var postVisitNotes: String; var prepDone: [String]
    }
    struct QuestionDTO: Codable { var text: String; var createdAt: Date; var asked: Bool }
    struct QoLDTO: Codable { var date: Date; var answers: [Int]; var total: Int }
    struct NutriDTO: Codable { var food: String; var verdict: String; var note: String }

    var profile: ProfileDTO?
    var symptoms: [SymptomDTO] = []
    var bowelMovements: [BMDTO] = []
    var foods: [FoodDTO] = []
    var triggers: [TriggerDTO] = []
    var hydration: [HydrationDTO] = []
    var medications: [MedDTO] = []
    var doses: [DoseDTO] = []
    var providers: [ProviderDTO] = []
    var appointments: [ApptDTO] = []
    var questions: [QuestionDTO] = []
    var qolCheckins: [QoLDTO] = []
    /// Optional so backups made before FR-16 still decode.
    var nutritionistRules: [NutriDTO]? = nil
}

enum ExportError: LocalizedError {
    case badPassphrase, corrupt
    var errorDescription: String? {
        switch self {
        case .badPassphrase: return "Wrong passphrase, or the file is damaged."
        case .corrupt: return "This file is not a valid IBD Aide backup."
        }
    }
}

@MainActor
enum ExportManager {

    // MARK: Build / apply envelope

    static func buildEnvelope(context: ModelContext) throws -> ExportEnvelope {
        var env = ExportEnvelope()
        if let p = try context.fetch(FetchDescriptor<UserProfile>()).first {
            env.profile = .init(name: p.name, diagnosis: p.diagnosisRaw, diagnosisDate: p.diagnosisDate, flareMode: p.flareMode)
        }
        env.symptoms = try context.fetch(FetchDescriptor<SymptomEntry>()).map {
            .init(date: $0.date, abdominalPain: $0.abdominalPain, wellbeing: $0.wellbeing, fatigue: $0.fatigue,
                  nausea: $0.nausea, jointPain: $0.jointPain, skinIssues: $0.skinIssues, eyeIssues: $0.eyeIssues,
                  mouthUlcers: $0.mouthUlcers, weightLbs: $0.weightLbs, sleepHours: $0.sleepHours, mood: $0.mood, notes: $0.notes)
        }
        env.bowelMovements = try context.fetch(FetchDescriptor<BowelMovementEntry>()).map {
            .init(date: $0.date, bristol: $0.bristol, blood: $0.blood, urgency: $0.urgency, nighttime: $0.nighttime)
        }
        env.foods = try context.fetch(FetchDescriptor<FoodEntry>()).map {
            .init(date: $0.date, name: $0.name, caffeine: $0.caffeine, alcohol: $0.alcohol, source: $0.source)
        }
        env.triggers = try context.fetch(FetchDescriptor<TriggerFood>()).map { .init(name: $0.name, origin: $0.origin) }
        env.hydration = try context.fetch(FetchDescriptor<HydrationEntry>()).map { .init(date: $0.date, glasses: $0.glasses) }
        env.medications = try context.fetch(FetchDescriptor<Medication>()).map {
            .init(id: $0.id, name: $0.name, dose: $0.dose, kind: $0.kindRaw, prescriber: $0.prescriber,
                  scheduleTimes: $0.scheduleTimes, intervalWeeks: $0.intervalWeeks,
                  pillsRemaining: $0.pillsRemaining, refillDate: $0.refillDate, active: $0.active)
        }
        env.doses = try context.fetch(FetchDescriptor<DoseEvent>()).map {
            .init(medicationID: $0.medicationID, scheduledAt: $0.scheduledAt, recordedAt: $0.recordedAt, status: $0.statusRaw)
        }
        env.providers = try context.fetch(FetchDescriptor<Provider>()).map {
            .init(id: $0.id, name: $0.name, role: $0.roleRaw, phone: $0.phone, email: $0.email,
                  address: $0.address, portalURL: $0.portalURL, notes: $0.notes)
        }
        env.appointments = try context.fetch(FetchDescriptor<Appointment>()).map {
            .init(type: $0.typeRaw, date: $0.date, providerID: $0.providerID, locationNote: $0.locationNote,
                  recurringWeeks: $0.recurringWeeks, reminderOffsetsHours: $0.reminderOffsetsHours,
                  preVisitNotes: $0.preVisitNotes, postVisitNotes: $0.postVisitNotes, prepDone: $0.prepDone)
        }
        env.questions = try context.fetch(FetchDescriptor<VisitQuestion>()).map {
            .init(text: $0.text, createdAt: $0.createdAt, asked: $0.asked)
        }
        env.qolCheckins = try context.fetch(FetchDescriptor<QoLCheckin>()).map {
            .init(date: $0.date, answers: $0.answers, total: $0.total)
        }
        env.nutritionistRules = try context.fetch(FetchDescriptor<NutritionistRule>()).map {
            .init(food: $0.foodName, verdict: $0.verdictRaw, note: $0.note)
        }
        return env
    }

    /// Replaces all existing data with the envelope's contents.
    static func apply(_ env: ExportEnvelope, context: ModelContext) throws {
        // wipe
        try context.delete(model: UserProfile.self)
        try context.delete(model: SymptomEntry.self)
        try context.delete(model: BowelMovementEntry.self)
        try context.delete(model: FoodEntry.self)
        try context.delete(model: TriggerFood.self)
        try context.delete(model: HydrationEntry.self)
        try context.delete(model: Medication.self)
        try context.delete(model: DoseEvent.self)
        try context.delete(model: Provider.self)
        try context.delete(model: Appointment.self)
        try context.delete(model: VisitQuestion.self)
        try context.delete(model: QoLCheckin.self)
        try context.delete(model: ScannedProduct.self)
        try context.delete(model: NewsItem.self)
        try context.delete(model: NutritionistRule.self)
        // restore
        let profile = UserProfile()
        if let p = env.profile {
            profile.name = p.name; profile.diagnosisRaw = p.diagnosis
            profile.diagnosisDate = p.diagnosisDate; profile.flareMode = p.flareMode
        }
        profile.onboarded = true
        context.insert(profile)

        for d in env.symptoms {
            let m = SymptomEntry(date: d.date)
            m.abdominalPain = d.abdominalPain; m.wellbeing = d.wellbeing; m.fatigue = d.fatigue
            m.nausea = d.nausea; m.jointPain = d.jointPain; m.skinIssues = d.skinIssues
            m.eyeIssues = d.eyeIssues; m.mouthUlcers = d.mouthUlcers
            m.weightLbs = d.weightLbs; m.sleepHours = d.sleepHours; m.mood = d.mood; m.notes = d.notes
            context.insert(m)
        }
        for d in env.bowelMovements {
            let m = BowelMovementEntry(date: d.date, bristol: d.bristol, blood: d.blood, urgency: d.urgency)
            m.nighttime = d.nighttime
            context.insert(m)
        }
        for d in env.foods {
            let m = FoodEntry(date: d.date, name: d.name)
            m.caffeine = d.caffeine; m.alcohol = d.alcohol; m.source = d.source
            context.insert(m)
        }
        for d in env.triggers { context.insert(TriggerFood(name: d.name, origin: d.origin)) }
        for d in env.hydration { context.insert(HydrationEntry(date: d.date, glasses: d.glasses)) }
        for d in env.medications {
            let m = Medication(name: d.name)
            m.id = d.id; m.dose = d.dose; m.kindRaw = d.kind; m.prescriber = d.prescriber
            m.scheduleTimes = d.scheduleTimes; m.intervalWeeks = d.intervalWeeks
            m.pillsRemaining = d.pillsRemaining; m.refillDate = d.refillDate; m.active = d.active
            context.insert(m)
        }
        for d in env.doses {
            let m = DoseEvent(medicationID: d.medicationID, scheduledAt: d.scheduledAt,
                              status: DoseStatus(rawValue: d.status) ?? .taken)
            m.recordedAt = d.recordedAt
            context.insert(m)
        }
        for d in env.providers {
            let m = Provider(name: d.name)
            m.id = d.id; m.roleRaw = d.role; m.phone = d.phone; m.email = d.email
            m.address = d.address; m.portalURL = d.portalURL; m.notes = d.notes
            context.insert(m)
        }
        for d in env.appointments {
            let m = Appointment(type: AppointmentType(rawValue: d.type) ?? .officeVisit, date: d.date)
            m.providerID = d.providerID; m.locationNote = d.locationNote; m.recurringWeeks = d.recurringWeeks
            m.reminderOffsetsHours = d.reminderOffsetsHours; m.preVisitNotes = d.preVisitNotes
            m.postVisitNotes = d.postVisitNotes; m.prepDone = d.prepDone
            context.insert(m)
        }
        for d in env.questions {
            let m = VisitQuestion(text: d.text)
            m.createdAt = d.createdAt; m.asked = d.asked
            context.insert(m)
        }
        for d in env.qolCheckins { context.insert(QoLCheckin(date: d.date, answers: d.answers)) }
        for d in env.nutritionistRules ?? [] {
            context.insert(NutritionistRule(foodName: d.food, verdictRaw: d.verdict, note: d.note))
        }
        try context.save()
    }

    // MARK: Crypto

    static func encrypt(_ env: ExportEnvelope, passphrase: String) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let json = try encoder.encode(env)
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let key = pbkdf2Key(passphrase: passphrase, salt: salt)
        let sealed = try AES.GCM.seal(json, using: key)
        guard let combined = sealed.combined else { throw ExportError.corrupt }
        return salt + combined
    }

    static func decrypt(_ data: Data, passphrase: String) throws -> ExportEnvelope {
        guard data.count > 16 + 28 else { throw ExportError.corrupt }
        let salt = data.prefix(16)
        let combined = data.dropFirst(16)
        let key = pbkdf2Key(passphrase: passphrase, salt: Data(salt))
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let json = try AES.GCM.open(box, using: key)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(ExportEnvelope.self, from: json)
        } catch is DecodingError {
            throw ExportError.corrupt
        } catch {
            throw ExportError.badPassphrase
        }
    }

    static func pbkdf2Key(passphrase: String, salt: Data, iterations: Int = 600_000) -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let saltBytes = [UInt8](salt)
        passphrase.withCString { pw in
            _ = CCKeyDerivationPBKDF(
                CCPBKDFAlgorithm(kCCPBKDF2),
                pw, strlen(pw),
                saltBytes, saltBytes.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                UInt32(iterations),
                &derived, derived.count)
        }
        return SymmetricKey(data: Data(derived))
    }
}

// MARK: - FileDocument for fileExporter

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
