import Foundation
import CoreLocation

@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var currentLocation: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var cityName: String = ""
    var isLoading: Bool = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        authorizationStatus = manager.authorizationStatus
    }

    func requestAndFetch() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            fetchOnce()
        default:
            break
        }
    }

    private func fetchOnce() {
        isLoading = true
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        isLoading = false
        Task { await reverseGeocode(location) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            fetchOnce()
        }
    }

    @MainActor
    private func reverseGeocode(_ location: CLLocation) async {
        let geocoder = CLGeocoder()
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            cityName = placemark.locality ?? placemark.administrativeArea ?? ""
        }
    }
}
