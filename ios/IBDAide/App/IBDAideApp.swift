import SwiftUI
import SwiftData

@main
struct IBDAideApp: App {
    let container: ModelContainer
    @StateObject private var lock = AppLockManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            container = try ModelContainer(for: Schema([
                UserProfile.self, SymptomEntry.self, BowelMovementEntry.self, FoodEntry.self,
                TriggerFood.self, HydrationEntry.self, Medication.self, DoseEvent.self,
                Provider.self, Appointment.self, VisitQuestion.self, QoLCheckin.self,
                ScannedProduct.self, NewsItem.self, NutritionistRule.self,
            ]))
        } catch {
            fatalError("Could not create data store: \(error)")
        }
        NotificationManager.shared.configure(container: container)
        Self.applyFileProtection()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .environmentObject(lock)
                .overlay {
                    if lock.isLocked {
                        LockScreenView(lock: lock)
                            .transition(.opacity)
                    }
                }
                .onAppear { lock.lockIfNeededOnLaunch() }
                .onChange(of: scenePhase) { _, phase in
                    lock.handleScenePhase(phase)
                }
        }
        .modelContainer(container)
    }

    /// NFR-1 / iOS spec §2.1: mark the app's data store with complete file protection
    /// so it is AES-encrypted at rest via iOS Data Protection (Secure Enclave keys).
    private static func applyFileProtection() {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        if let files = try? fm.contentsOfDirectory(at: support, includingPropertiesForKeys: nil) {
            for url in files {
                try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
            }
        }
        try? fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: support.path)
    }
}
