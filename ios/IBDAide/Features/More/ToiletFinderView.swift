import SwiftUI
import MapKit
import CoreLocation

/// FR-11: nearby public restrooms via MapKit search.
/// Location is used transiently and never stored (NFR-2).
struct ToiletFinderView: View {
    @StateObject private var locator = LocationProvider()
    @State private var results: [RestroomPlace] = []
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var searching = false
    @State private var message: String?

    struct RestroomPlace: Identifiable {
        let id = UUID()
        let name: String
        let coordinate: CLLocationCoordinate2D
        let mapItem: MKMapItem
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camera) {
                UserAnnotation()
                ForEach(results) { place in
                    Marker(place.name, systemImage: "toilet.fill", coordinate: place.coordinate)
                        .tint(Theme.accent)
                }
            }
            .frame(maxHeight: .infinity)

            VStack(spacing: 8) {
                if let message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await search() }
                } label: {
                    Label(searching ? "Searching…" : "Find restrooms near me", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(searching)

                if !results.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(results) { place in
                                Button {
                                    place.mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
                                } label: {
                                    Text(place.name).font(.caption)
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(Theme.accentSoft, in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Restroom finder")
        .onAppear { locator.request() }
    }

    private func search() async {
        searching = true; message = nil
        defer { searching = false }
        guard let location = locator.location ?? locator.awaitLocation() else {
            message = "Location unavailable. Allow location access in Settings, or search in the Maps app."
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "public restroom"
        request.region = MKCoordinateRegion(center: location.coordinate,
                                            latitudinalMeters: 3000, longitudinalMeters: 3000)
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems.map {
                RestroomPlace(name: $0.name ?? "Restroom",
                              coordinate: $0.placemark.coordinate,
                              mapItem: $0)
            }
            camera = .region(MKCoordinateRegion(center: location.coordinate,
                                                latitudinalMeters: 3000, longitudinalMeters: 3000))
            if results.isEmpty { message = "No public restrooms found nearby. Try the Maps app for a wider search." }
        } catch {
            message = "Search failed: \(error.localizedDescription)"
        }
    }
}

/// Minimal while-in-use location wrapper.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    /// Last-known synchronous fallback.
    func awaitLocation() -> CLLocation? { manager.location }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse { manager.requestLocation() }
    }
}
