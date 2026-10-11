import SwiftUI

/// More tab: Doctor report (screen 6), News, Toilet finder, QoL check-in, Settings.
struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { ReportView() } label: {
                        Label("Doctor report (PDF)", systemImage: "doc.text.fill")
                    }
                    NavigationLink { QoLCheckinView() } label: {
                        Label("Quality-of-life check-in", systemImage: "checklist")
                    }
                }
                Section {
                    NavigationLink { NewsView() } label: {
                        Label("Treatment news", systemImage: "newspaper.fill")
                    }
                    NavigationLink { ToiletFinderView() } label: {
                        Label("Restroom finder", systemImage: "mappin.and.ellipse")
                    }
                }
                Section {
                    NavigationLink { NutritionistPlanView() } label: {
                        Label("Nutritionist plan", systemImage: "fork.knife.circle.fill")
                    }
                    NavigationLink { SourcesView() } label: {
                        Label("Medical sources & citations", systemImage: "text.book.closed.fill")
                    }
                    NavigationLink { SettingsView() } label: {
                        Label("Settings, backup & privacy", systemImage: "gearshape.fill")
                    }
                }
            }
            .navigationTitle("More")
        }
    }
}
