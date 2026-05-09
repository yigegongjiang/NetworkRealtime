import Foundation
import CoreLocation
import Logging

class LocationManager: NSObject, CLLocationManagerDelegate {
  static let shared = LocationManager()
  private var locationManager: CLLocationManager

  override private init() {
    locationManager = CLLocationManager()
    super.init()
    setupLocationManager()
  }

  private func setupLocationManager() {
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.distanceFilter = kCLDistanceFilterNone
  }

  private(set) var isUpdating = false

  func startUpdatingLocation() {
    guard !isUpdating else { return }
    locationManager.requestAlwaysAuthorization()
    locationManager.startUpdatingLocation()
    isUpdating = true
  }

  func stopUpdatingLocation() {
    locationManager.stopUpdatingLocation()
    isUpdating = false
  }

  // MARK: - CLLocationManagerDelegate

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // background task will keep running
    log.info("Location update: \(locations)")
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    log.error("Location update failed: \(error.localizedDescription)")
  }
}
