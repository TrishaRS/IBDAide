import SwiftUI
import SwiftData
import MapKit

/// Screen 4 — FR-6 care team + FR-7 appointments (+ Meds segment, screen 5).
struct CareView: View {
    enum Segment: String, CaseIterable { case appointments = "Appointments", team = "Care team", meds = "Meds" }
    @State private var segment: Segment = .appointments

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $segment) {
                    ForEach(Segment.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch segment {
                case .appointments: AppointmentsListView()
                case .team: ProvidersListView()
                case .meds: MedsView()
                }
            }
            .navigationTitle("Care")
        }
    }
}

// MARK: - Appointments (FR-7)

struct AppointmentsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @Query private var providers: [Provider]
    @Query(sort: \VisitQuestion.createdAt, order: .reverse) private var questions: [VisitQuestion]

    @State private var showEditor = false
    @State private var editing: Appointment?
    @State private var newQuestion = ""

    private var upcoming: [Appointment] { appointments.filter { $0.date >= Date().addingTimeInterval(-3600) } }
    private var past: [Appointment] { appointments.filter { $0.date < Date().addingTimeInterval(-3600) }.reversed() }

    var body: some View {
        List {
            Section("Questions to ask at my next visit") {
                ForEach(questions.filter { !$0.asked }) { q in
                    HStack {
                        Button {
                            q.asked = true; try? context.save()
                        } label: {
                            Image(systemName: "circle")
                        }
                        .buttonStyle(.plain)
                        Text(q.text)
                    }
                }
                .onDelete { idx in
                    let open = questions.filter { !$0.asked }
                    for i in idx { context.delete(open[i]) }
                    try? context.save()
                }
                HStack {
                    TextField("Add a question…", text: $newQuestion)
                    Button {
                        context.insert(VisitQuestion(text: newQuestion))
                        newQuestion = ""
                        try? context.save()
                    } label: { Image(systemName: "plus.circle.fill") }
                    .disabled(newQuestion.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Upcoming") {
                if upcoming.isEmpty { Text("No upcoming appointments.").foregroundStyle(.secondary) }
                ForEach(upcoming) { appt in
                    Button { editing = appt } label: { AppointmentRow(appt: appt, providers: providers) }
                        .buttonStyle(.plain)
                }
                .onDelete { idx in
                    for i in idx {
                        NotificationManager.shared.cancelAppointmentReminders(for: upcoming[i])
                        context.delete(upcoming[i])
                    }
                    try? context.save()
                }
            }

            if !past.isEmpty {
                Section("Past") {
                    ForEach(past.prefix(10)) { appt in
                        Button { editing = appt } label: { AppointmentRow(appt: appt, providers: providers) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showEditor) { AppointmentEditView(appointment: nil) }
        .sheet(item: $editing) { appt in AppointmentEditView(appointment: appt) }
    }
}

struct AppointmentRow: View {
    let appt: Appointment
    let providers: [Provider]

    private var providerName: String {
        providers.first { $0.id == appt.providerID }?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(appt.type.rawValue).font(.subheadline.bold())
                if let weeks = appt.recurringWeeks {
                    Text("every \(weeks) wks")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentSoft, in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                Spacer()
            }
            Text(appt.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption).foregroundStyle(.secondary)
            if !providerName.isEmpty {
                Text(providerName).font(.caption).foregroundStyle(.secondary)
            }
            if appt.type == .procedure {
                Text("Prep: \(appt.prepDone.count)/\(Appointment.prepChecklist.count) done")
                    .font(.caption2).foregroundStyle(appt.prepDone.count == Appointment.prepChecklist.count ? Theme.greenText : Theme.amberText)
            }
        }
    }
}

// MARK: - Providers (FR-6)

struct ProvidersListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Provider.name) private var providers: [Provider]
    @State private var showEditor = false
    @State private var editing: Provider?

    var body: some View {
        List {
            if providers.isEmpty {
                Text("Add your GI doctor, nurse line, infusion center, and pharmacy.")
                    .foregroundStyle(.secondary)
            }
            ForEach(providers) { p in
                Button { editing = p } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(p.name).font(.subheadline.bold())
                        Text(p.role.rawValue).font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 14) {
                            if !p.phone.isEmpty,
                               let telURL = URL(string: "tel:\(p.phone.filter { "0123456789+".contains($0) })") {
                                Link(destination: telURL) {
                                    Label("Call", systemImage: "phone.fill").font(.caption)
                                }
                            }
                            if !p.email.isEmpty, let mailURL = URL(string: "mailto:\(p.email)") {
                                Link(destination: mailURL) {
                                    Label("Email", systemImage: "envelope.fill").font(.caption)
                                }
                            }
                            if !p.address.isEmpty {
                                Button {
                                    openInMaps(address: p.address, name: p.name)
                                } label: {
                                    Label("Map", systemImage: "map.fill").font(.caption)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { idx in
                for i in idx { context.delete(providers[i]) }
                try? context.save()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showEditor) { ProviderEditView(provider: nil) }
        .sheet(item: $editing) { p in ProviderEditView(provider: p) }
    }

    private func openInMaps(address: String, name: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, _ in
            guard let placemark = placemarks?.first else { return }
            let item = MKMapItem(placemark: MKPlacemark(placemark: placemark))
            item.name = name
            item.openInMaps()
        }
    }
}
