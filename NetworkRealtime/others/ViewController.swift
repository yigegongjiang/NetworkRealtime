//
//  ViewController.swift
//  NetworkRealtime
//
//  Created by Hailv on 2025/01/14.
//

import UIKit
import ActivityKit
import Logging

class ViewController: UIViewController {
  @IBOutlet
  weak var shows: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()
    start()
  }

  func start() {
    LiveActivityManager.shared.startLiveActivity()

    NetworkSpeedMonitor.shared.startMonitoring { [weak self] stats in
      DispatchQueue.main.async {
        LiveActivityManager.shared.updateLiveActivity(
          dSpeed: stats.download.value,
          dUnit: stats.download.unit,
          uSpeed: stats.upload.value,
          uUnit: stats.upload.unit
        )

        let changed = "upload: " + stats.upload.formatted + "\n" + "download: " + stats.download.formatted
        log.info("Network speed: \(changed.replacingOccurrences(of: "\n", with: " / "))")
        self?.shows.text = changed
      }
    }
  }

  func stop() {
    NetworkSpeedMonitor.shared.stopMonitoring()
    LiveActivityManager.shared.stopLiveActivity()
  }

  @IBAction
  func restart(_ sender: Any) {
    stop()
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      self.start()
    }
  }

  deinit {
    stop()
  }
}
