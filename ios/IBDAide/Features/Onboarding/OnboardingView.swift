import SwiftUI
import SwiftData

/// Onboarding: disclaimer consent → profile → privacy/lock → notifications.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var lock: AppLockManager

    @State private var step = 0
    @State private var name = ""
    @State private var diagnosis: Diagnosis = .crohns
    @State private var diagnosisDate: Date = Date()
    @State private var hasDiagnosisDate = false
    @State private var enableLock = true
    @State private var acceptedDisclaimer = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $step) {
                    welcome.tag(0)
                    profileStep.tag(1)
                    privacyStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button(action: next) {
                    Text(step == 2 ? "Get started" : "Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(step == 0 && !acceptedDisclaimer)
                .padding()
            }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 64)).foregroundStyle(Theme.accent)
                Text("Welcome to IBD Aide").font(.largeTitle.bold())
                Text("A private companion for Crohn's disease, ulcerative colitis, and IBD-U. Your health data stays on this phone — encrypted, behind Face ID, never sold or shared.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary)
                GroupBox("Please read") {
                    Text(disclaimerText).font(.footnote).foregroundStyle(.secondary)
                }
                Toggle("I understand — IBD Aide is not medical advice", isOn: $acceptedDisclaimer)
                    .font(.subheadline.bold())
            }
            .padding()
        }
    }

    private var profileStep: some View {
        Form {
            Section("About you") {
                TextField("First name (optional)", text: $name)
                Picker("Diagnosis", selection: $diagnosis) {
                    ForEach(Diagnosis.allCases) { d in Text(d.rawValue).tag(d) }
                }
                Toggle("I know my diagnosis date", isOn: $hasDiagnosisDate)
                if hasDiagnosisDate {
                    DatePicker("Diagnosed", selection: $diagnosisDate, displayedComponents: .date)
                }
            }
            Section {
                Text(diagnosis == .crohns
                     ? "IBD Aide will track a modified Harvey-Bradshaw Index (HBI) from your logs."
                     : diagnosis == .ulcerativeColitis
                     ? "IBD Aide will track a modified Simple Clinical Colitis Activity Index (SCCAI) from your logs."
                     : "IBD Aide will track your overall symptom burden from your logs.")
                .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var privacyStep: some View {
        Form {
            Section("Privacy & security") {
                Toggle("Require \(lock.biometryLabel) to open the app", isOn: $enableLock)
                Label("All data is stored only on this phone, encrypted at rest.", systemImage: "internaldrive")
                Label("Data survives phone upgrades via your encrypted iCloud or computer backup.", systemImage: "arrow.triangle.2.circlepath")
                Label("Reminders never show health details on the lock screen.", systemImage: "bell.badge")
            }
            .font(.subheadline)
        }
    }

    private func next() {
        if step < 2 { step += 1; return }
        let profile = UserProfile()
        profile.name = name
        profile.diagnosis = diagnosis
        profile.diagnosisDate = hasDiagnosisDate ? diagnosisDate : nil
        profile.onboarded = true
        profile.appLockEnabled = enableLock
        context.insert(profile)
        try? context.save()
        lock.lockEnabled = enableLock
        Task { _ = await NotificationManager.shared.requestAuthorization() }
    }
}
