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
    _restart()
    
    // 添加应用程序进入前台的通知观察
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }
  
  @objc func applicationDidBecomeActive() {
    _restart()
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
    _restart()
  }
  
  func _restart() {
    stop()
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      self.start()
    }
  }

  deinit {
    stop()
    NotificationCenter.default.removeObserver(self)
  }
}
