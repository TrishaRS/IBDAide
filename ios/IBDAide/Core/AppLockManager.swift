import Foundation
import LocalAuthentication
import SwiftUI

/// FR-13: biometric app lock with device-passcode fallback.
/// Locks on backgrounding; unlocks with Face ID / Touch ID / passcode.
@MainActor
final class AppLockManager: ObservableObject {

    @Published var isLocked = false
    @Published var isAuthenticating = false
    @Published var lastError: String?

    /// Off until onboarding enables it, so first launch isn't locked out.
    @AppStorage("appLockEnabled") var lockEnabled = false
    /// grace period in seconds before a backgrounded app relocks (0 = immediately)
    @AppStorage("appLockGraceSeconds") var graceSeconds = 0

    private var backgroundedAt: Date?

    var biometryLabel: String {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return "Passcode" }
        switch ctx.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return "Passcode"
        }
    }

    func lockIfNeededOnLaunch() {
        isLocked = lockEnabled
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard lockEnabled else { isLocked = false; return }
        switch phase {
        case .background:
            backgroundedAt = Date()
        case .active:
            if let t = backgroundedAt, Date().timeIntervalSince(t) >= Double(graceSeconds) {
                isLocked = true
            }
            backgroundedAt = nil
            if isLocked && !isAuthenticating {
                Task { await unlock() }
            }
        default:
            break
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        lastError = nil

        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on device — cannot protect; unlock but surface a warning.
            lastError = "No device passcode is set. Set a passcode in Settings to protect your data."
            isLocked = false
            return
        }
        do {
            let ok = try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                                  localizedReason: "Unlock IBD Aide to view your health data")
            if ok { isLocked = false }
        } catch {
            lastError = "Authentication failed. Tap to try again."
        }
    }
}

/// Full-screen cover shown while locked. Shows no health data (FR-13).
struct LockScreenView: View {
    @ObservedObject var lock: AppLockManager

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.accent)
                Text("IBD Aide is locked")
                    .font(.title2.bold())
                if let err = lock.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                Button {
                    Task { await lock.unlock() }
                } label: {
                    Label("Unlock with \(lock.biometryLabel)", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
    }
}
