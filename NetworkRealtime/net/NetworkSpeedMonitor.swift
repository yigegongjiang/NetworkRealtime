import Foundation
import Network
import Darwin

class NetworkSpeedMonitor {
  static let shared = NetworkSpeedMonitor()

  // MARK: - Types

  struct NetworkSpeed {
    let value: Double
    let unit: String

    var formatted: String {
      return "\(value)\(unit)"
    }
  }

  struct NetworkStats {
    let download: NetworkSpeed
    let upload: NetworkSpeed
  }

  // MARK: - Private Properties

  private var previousStats: (bytesIn: UInt64, bytesOut: UInt64, timestamp: Date, reset: Bool)
  private var timer: DispatchSourceTimer?
  private var updateHandler: ((NetworkStats) -> Void)?

  private let locationManager = LocationManager.shared

  private let validInterfaceTypes = ["en", "pdp_ip", "rmnet", "ppp", "wwan"]

  // MARK: - Initialization

  private init() {
    previousStats = (0, 0, Date(), true)
  }

  // MARK: - Public Methods

  func startMonitoring(updateInterval: TimeInterval = 1.0, handler: @escaping (NetworkStats) -> Void) {
    self.updateHandler = handler
    locationManager.startUpdatingLocation()

    self.updateNetworkSpeed()

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
    timer.schedule(deadline: .now(), repeating: updateInterval)
    timer.setEventHandler { [weak self] in
      self?.updateNetworkSpeed()
    }
    timer.resume()
    self.timer = timer
  }

  func stopMonitoring() {
    timer?.cancel()
    timer = nil
    locationManager.stopUpdatingLocation()
  }

  // MARK: - Private Methods

  private func formatSpeed(_ bytesPerSecond: Double) -> NetworkSpeed? {
    switch bytesPerSecond {
    case 0..<1024: // < 1KB/s
      return NetworkSpeed(value: Double(Int(bytesPerSecond)), unit: "b")
    case 1024..<(1024 * 1024): // < 1MB/s
      return NetworkSpeed(value: Double(Int(bytesPerSecond / 1024)), unit: "k")
    case (1024 * 1024)..<(1024 * 1024 * 1024): // < 1GB/s
      return NetworkSpeed(value: Double(String(format: "%.1f", bytesPerSecond / 1024 / 1024))!, unit: "m")
    default:
      return nil
    }
  }

  private func updateNetworkSpeed() {
    guard let (currentBytesIn, currentBytesOut) = getNetworkBytes() else { return }

    let now = Date()
    let timeInterval = now.timeIntervalSince(previousStats.timestamp)

    // check for data rollback (e.g. device reboot or counter reset)
    if currentBytesIn < previousStats.bytesIn || currentBytesOut < previousStats.bytesOut {
      previousStats = (0, 0, Date(), true)
      return
    }

    // calculate speed
    let downloadBytesPerSec = Double(currentBytesIn - previousStats.bytesIn) / timeInterval
    let uploadBytesPerSec = Double(currentBytesOut - previousStats.bytesOut) / timeInterval

    // format speed
    guard let downloadSpeed = formatSpeed(downloadBytesPerSec),
          let uploadSpeed = formatSpeed(uploadBytesPerSec) else {
      previousStats = (currentBytesIn, currentBytesOut, now, false)
      return
    }

    if !previousStats.reset, let updateHandler = self.updateHandler {
      let stats = NetworkStats(download: downloadSpeed, upload: uploadSpeed)
      updateHandler(stats)
    }

    // update history
    previousStats = (currentBytesIn, currentBytesOut, now, false)
  }

  private func getNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64)? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return nil }
    defer { freeifaddrs(ifaddr) }

    var totalBytesIn: UInt64 = 0
    var totalBytesOut: UInt64 = 0

    var pointer = ifaddr
    while pointer != nil {
      defer { pointer = pointer?.pointee.ifa_next }

      guard let info = pointer?.pointee,
            let name = String(cString: info.ifa_name, encoding: .utf8),
            let addr = info.ifa_addr,
            addr.pointee.sa_family == AF_LINK else { continue }

      // check if it's a valid network interface
      let isValidInterface = validInterfaceTypes.contains { name.hasPrefix($0) }
      guard isValidInterface else { continue }

      guard let data = info.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }

      totalBytesIn += UInt64(data.pointee.ifi_ibytes)
      totalBytesOut += UInt64(data.pointee.ifi_obytes)
    }

    return (totalBytesIn, totalBytesOut)
  }
}
