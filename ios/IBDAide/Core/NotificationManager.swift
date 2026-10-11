import Foundation
import UserNotifications
import SwiftData

/// FR-7 / FR-8: local notifications only — no push server.
/// Privacy: notification content is generic; no medication names, no health data
/// on the lock screen. Taken/Skip actions carry the medication ID in userInfo only.
@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()
    static let medCategory = "MED_DOSE"

    var modelContainer: ModelContainer?

    func configure(container: ModelContainer) {
        modelContainer = container
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let taken = UNNotificationAction(identifier: "TAKEN", title: "Taken", options: [])
        let skip = UNNotificationAction(identifier: "SKIP", title: "Skip", options: [])
        let category = UNNotificationCategory(identifier: Self.medCategory, actions: [taken, skip],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Medication reminders (daily, repeating)

    func scheduleMedReminders(for med: Medication) {
        cancelMedReminders(for: med)
        guard med.active, med.kind == .oral || med.kind == .biologic else { return }
        let center = UNUserNotificationCenter.current()
        for minutes in med.scheduleTimes {
            let content = UNMutableNotificationContent()
            content.title = "IBD Aide"
            content.body = "You have a medication reminder."   // generic on purpose
            content.sound = .default
            content.categoryIdentifier = Self.medCategory
            content.userInfo = ["medicationID": med.id.uuidString, "minutes": minutes]

            var comps = DateComponents()
            comps.hour = minutes / 60
            comps.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(identifier: "med-\(med.id.uuidString)-\(minutes)",
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelMedReminders(for med: Medication) {
        let ids = med.scheduleTimes.map { "med-\(med.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:
            ids + [("med-\(med.id.uuidString)")])
    }

    // MARK: Refill alerts

    func scheduleRefillAlert(for med: Medication, daysBefore: Int = 5) {
        let id = "refill-\(med.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        guard let refill = med.refillDate else { return }
        let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: refill) ?? refill
        guard fireDate > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "IBD Aide"
        content.body = "A refill is coming up."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: fireDate)
        let request = UNNotificationRequest(identifier: id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Appointment reminders

    func scheduleAppointmentReminders(for appt: Appointment) {
        cancelAppointmentReminders(for: appt)
        let center = UNUserNotificationCenter.current()
        for hours in appt.reminderOffsetsHours {
            guard let fireDate = Calendar.current.date(byAdding: .hour, value: -hours, to: appt.date),
                  fireDate > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "IBD Aide"
            content.body = "You have an upcoming appointment."
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let request = UNNotificationRequest(identifier: "appt-\(appt.id.uuidString)-\(hours)",
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            center.add(request)
        }
    }

    func cancelAppointmentReminders(for appt: Appointment) {
        let ids = appt.reminderOffsetsHours.map { "appt-\(appt.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: Delegate — handle Taken/Skip from the notification

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let idString = userInfo["medicationID"] as? String,
              let medID = UUID(uuidString: idString) else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            guard let container = self.modelContainer else { return }
            let status: DoseStatus? = action == "TAKEN" ? .taken : action == "SKIP" ? .skipped : nil
            guard let status else { return }
            let event = DoseEvent(medicationID: medID, scheduledAt: Date(), status: status)
            container.mainContext.insert(event)
            if status == .taken {
                // decrement pill count if tracked
                let descriptor = FetchDescriptor<Medication>(predicate: #Predicate { $0.id == medID })
                if let med = try? container.mainContext.fetch(descriptor).first,
                   let remaining = med.pillsRemaining, remaining > 0 {
                    med.pillsRemaining = remaining - 1
                }
            }
            try? container.mainContext.save()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
