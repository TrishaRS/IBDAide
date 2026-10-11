import SwiftUI
import SwiftData

/// FR-6: create/edit a provider or facility.
struct ProviderEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let provider: Provider?

    @State private var name = ""
    @State private var role: ProviderRole = .giDoctor
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var portalURL = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Provider / facility") {
                    TextField("Name", text: $name)
                    Picker("Role", selection: $role) {
                        ForEach(ProviderRole.allCases) { r in Text(r.rawValue).tag(r) }
                    }
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("Address", text: $address, axis: .vertical).lineLimit(2...3)
                    TextField("Patient portal URL", text: $portalURL).keyboardType(.URL).textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextField("Notes…", text: $notes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(provider == nil ? "New contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let p = provider ?? Provider()
                        p.name = name; p.role = role; p.phone = phone; p.email = email
                        p.address = address; p.portalURL = portalURL; p.notes = notes
                        if provider == nil { context.insert(p) }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let p = provider else { return }
                name = p.name; role = p.role; phone = p.phone; email = p.email
                address = p.address; portalURL = p.portalURL; notes = p.notes
            }
        }
    }
}
