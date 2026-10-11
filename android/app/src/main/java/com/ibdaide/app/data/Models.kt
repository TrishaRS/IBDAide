package com.ibdaide.app.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

// Enums stored as raw strings — same values as iOS for the shared export schema.

enum class Diagnosis(val label: String) {
    CROHNS("Crohn's disease"),
    ULCERATIVE_COLITIS("Ulcerative colitis"),
    IBD_U("IBD-unclassified");

    companion object {
        fun fromLabel(s: String?) = entries.firstOrNull { it.label == s } ?: CROHNS
    }
}

enum class ProviderRole(val label: String) {
    GI_DOCTOR("GI doctor"), NURSE("Nurse"), INFUSION_CENTER("IV / infusion center"),
    PHARMACY("Pharmacy"), OTHER("Other");
    companion object { fun fromLabel(s: String?) = entries.firstOrNull { it.label == s } ?: OTHER }
}

enum class AppointmentType(val label: String) {
    OFFICE_VISIT("Office visit"), TELEHEALTH("Telehealth"), INFUSION("IV infusion"),
    LAB_WORK("Lab work"), PROCEDURE("Procedure / colonoscopy");
    companion object { fun fromLabel(s: String?) = entries.firstOrNull { it.label == s } ?: OFFICE_VISIT }
}

enum class MedicationKind(val label: String) {
    ORAL("Oral"), BIOLOGIC("Biologic (injection)"), INFUSION("Biologic (IV infusion)");
    companion object { fun fromLabel(s: String?) = entries.firstOrNull { it.label == s } ?: ORAL }
}

// All timestamps are epoch millis UTC. Cross-references by UUID string (flat schema, like iOS).

@Entity(tableName = "user_profile")
data class UserProfile(
    @PrimaryKey val id: Int = 1,
    val name: String = "",
    val diagnosisRaw: String = Diagnosis.CROHNS.label,
    val diagnosisDate: Long? = null,
    val flareMode: Boolean = false,
    val onboarded: Boolean = false,
    val appLockEnabled: Boolean = true,
) { val diagnosis: Diagnosis get() = Diagnosis.fromLabel(diagnosisRaw) }

@Entity(tableName = "symptom_entries")
data class SymptomEntry(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val abdominalPain: Int? = null,   // 0–10
    val wellbeing: Int? = null,       // 0–4
    val fatigue: Int? = null,         // 0–3
    val nausea: Boolean = false,
    val jointPain: Boolean = false,
    val skinIssues: Boolean = false,
    val eyeIssues: Boolean = false,
    val mouthUlcers: Boolean = false,
    val weightLbs: Double? = null,
    val sleepHours: Double? = null,
    val mood: Int? = null,
    val notes: String = "",
)

@Entity(tableName = "bm_entries")
data class BowelMovementEntry(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val bristol: Int = 4,             // 1–7
    val blood: Boolean = false,
    val urgency: Int = 0,             // 0–3
    val nighttime: Boolean = false,
)

@Entity(tableName = "food_entries")
data class FoodEntry(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val name: String = "",
    val caffeine: Boolean = false,
    val alcohol: Boolean = false,
    val source: String = "manual",    // manual | barcode | dish-scan
)

@Entity(tableName = "trigger_foods")
data class TriggerFood(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val origin: String = "user",      // user | suggested
)

@Entity(tableName = "hydration_entries")
data class HydrationEntry(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    val glasses: Int = 1,
)

@Entity(tableName = "medications")
data class Medication(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val dose: String = "",
    val kindRaw: String = MedicationKind.ORAL.label,
    val prescriber: String = "",
    /** comma-separated minutes-from-midnight, e.g. "480,720" */
    val scheduleTimes: String = "",
    val intervalWeeks: Int? = null,
    val pillsRemaining: Int? = null,
    val refillDate: Long? = null,
    val active: Boolean = true,
    val createdAt: Long = System.currentTimeMillis(),
) {
    val kind: MedicationKind get() = MedicationKind.fromLabel(kindRaw)
    val times: List<Int> get() = scheduleTimes.split(",").mapNotNull { it.trim().toIntOrNull() }.sorted()
}

@Entity(tableName = "dose_events")
data class DoseEvent(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val medicationID: String = "",
    val scheduledAt: Long = System.currentTimeMillis(),
    val recordedAt: Long = System.currentTimeMillis(),
    val status: String = "taken",     // taken | skipped
)

@Entity(tableName = "providers")
data class Provider(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val roleRaw: String = ProviderRole.GI_DOCTOR.label,
    val phone: String = "",
    val email: String = "",
    val address: String = "",
    val portalURL: String = "",
    val notes: String = "",
) { val role: ProviderRole get() = ProviderRole.fromLabel(roleRaw) }

@Entity(tableName = "appointments")
data class Appointment(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val typeRaw: String = AppointmentType.OFFICE_VISIT.label,
    val date: Long = System.currentTimeMillis(),
    val providerID: String? = null,
    val locationNote: String = "",
    val recurringWeeks: Int? = null,
    /** comma-separated hours-before offsets, e.g. "168,24,2" */
    val reminderOffsetsHours: String = "168,24,2",
    val preVisitNotes: String = "",
    val postVisitNotes: String = "",
    /** newline-separated completed prep-checklist items */
    val prepDone: String = "",
) {
    val type: AppointmentType get() = AppointmentType.fromLabel(typeRaw)
    val offsets: List<Int> get() = reminderOffsetsHours.split(",").mapNotNull { it.trim().toIntOrNull() }
    val prepDoneSet: Set<String> get() = prepDone.split("\n").filter { it.isNotBlank() }.toSet()

    companion object {
        val PREP_CHECKLIST = listOf(
            "Confirm prep prescription picked up",
            "Start low-fiber diet (2 days before)",
            "Clear liquids only (1 day before)",
            "Begin prep drink as instructed",
            "Arrange ride home",
            "Nothing by mouth after midnight",
        )
    }
}

@Entity(tableName = "visit_questions")
data class VisitQuestion(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val text: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val appointmentID: String? = null,
    val asked: Boolean = false,
)

@Entity(tableName = "qol_checkins")
data class QoLCheckin(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val date: Long = System.currentTimeMillis(),
    /** comma-separated 8 answers, each 0–4 */
    val answers: String = "",
    val total: Int = 0,
) {
    companion object {
        val QUESTIONS = listOf(
            "I have felt in control of my IBD",
            "My IBD has NOT interfered with daily activities",
            "I have NOT missed planned activities because of IBD",
            "I have slept well",
            "My energy levels have been good",
            "I have felt free of significant pain or discomfort",
            "I have NOT felt anxious or depressed about my IBD",
            "I believe my current treatment is working",
        )
    }
}

@Entity(tableName = "scanned_products")
data class ScannedProduct(
    @PrimaryKey val barcode: String = "",
    val name: String = "",
    val brand: String = "",
    val ingredientsText: String = "",
    val fetchedAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "news_items")
data class NewsItem(
    @PrimaryKey val guid: String = "",
    val title: String = "",
    val source: String = "",
    val link: String = "",
    val publishedAt: Long = System.currentTimeMillis(),
    val summary: String = "",
    val isRead: Boolean = false,
)
