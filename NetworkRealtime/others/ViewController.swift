//
//  ViewController.swift
//  NetworkRealtime
//
//  Created by Hailv on 2025/01/14.
//

import UIKit
import Logging

class ViewController: UIViewController {
  private let speedLabelInset: CGFloat = 24

  @IBOutlet
  weak var shows: UILabel!

  override func viewDidLoad() {
    super.viewDidLoad()
    configureSpeedLabel()
    configurePiPControls()

    PiPSpeedController.shared.attach(to: view)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  @objc func applicationDidBecomeActive() {
    start()
  }

  func start() {
    NetworkSpeedMonitor.shared.startMonitoring { [weak self] stats in
      DispatchQueue.main.async {
        PiPSpeedController.shared.update(
          uText: stats.upload.formatted,
          dText: stats.download.formatted
        )

        let changed = Self.formattedStatsText(stats)
        log.info("Network speed: \(changed.replacingOccurrences(of: "\n", with: " / "))")
        self?.shows.text = changed
      }
    }
  }

  @objc private func startPiP() { PiPSpeedController.shared.start() }
  @objc private func stopPiP() { PiPSpeedController.shared.stop() }

  @objc private func presetChanged(_ sender: UISegmentedControl) {
    let preset = SpeedPreset.allCases[sender.selectedSegmentIndex]
    PiPSpeedController.shared.setPreset(preset)
  }

  private func configureSpeedLabel() {
    shows.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .regular)
    shows.textAlignment = .left

    NSLayoutConstraint.activate([
      shows.leadingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.leadingAnchor,
        constant: speedLabelInset
      ),
      shows.trailingAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.trailingAnchor,
        constant: -speedLabelInset
      )
    ])
  }

  private func configurePiPControls() {
    let startButton = makePiPButton(title: "Start PiP", action: #selector(startPiP))
    let stopButton = makePiPButton(title: "Stop PiP", action: #selector(stopPiP))
    let buttonRow = UIStackView(arrangedSubviews: [startButton, stopButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 16

    let presetControl = makePresetControl()

    let stack = UIStackView(arrangedSubviews: [presetControl, buttonRow])
    stack.axis = .vertical
    stack.spacing = 16
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.bottomAnchor.constraint(
        equalTo: view.safeAreaLayoutGuide.bottomAnchor,
        constant: -speedLabelInset
      ),
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      presetControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
    ])
  }

  private func makePresetControl() -> UISegmentedControl {
    let titles = SpeedPreset.allCases.map { String($0.rawValue) }
    let control = UISegmentedControl(items: titles)
    control.selectedSegmentIndex = SpeedPreset.allCases.firstIndex(of: .current) ?? 0
    control.addTarget(self, action: #selector(presetChanged(_:)), for: .valueChanged)
    return control
  }

  private func makePiPButton(title: String, action: Selector) -> UIButton {
    var config = UIButton.Configuration.tinted()
    config.title = title
    let button = UIButton(configuration: config, primaryAction: nil)
    button.addTarget(self, action: action, for: .touchUpInside)
    return button
  }

  private static func formattedStatsText(_ stats: NetworkSpeedMonitor.NetworkStats) -> String {
    let lines = [
      formattedSpeedLine(label: "upload", value: stats.upload.formatted),
      formattedSpeedLine(label: "download", value: stats.download.formatted)
    ]

    return lines.joined(separator: "\n")
  }

  private static func formattedSpeedLine(label: String, value: String) -> String {
    let labelColumnWidth = 8
    let paddedLabel = label.padding(
      toLength: labelColumnWidth,
      withPad: " ",
      startingAt: 0
    )

    return "\(paddedLabel): \(value)"
  }

  deinit {
    NetworkSpeedMonitor.shared.stopMonitoring()
    NotificationCenter.default.removeObserver(self)
  }
}
