//
//  ViewController.swift
//  NetworkRealtime
//
//  Created by Hailv on 2025/01/14.
//

import UIKit
import Logging

class ViewController: UIViewController {
  @IBOutlet
  weak var shows: UILabel!

  @IBOutlet
  weak var customField: UITextField!

  // segment 在 didBecomeActive 反查 SpeedPreset.current, 让 widget / 控制中心改档后回 App 也能看到.
  private var presetControl: UISegmentedControl?

  override func viewDidLoad() {
    super.viewDidLoad()
    configureLayout()
    configureCustomField()

    PiPSpeedController.shared.attach(to: view)

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  private func configureCustomField() {
    customField.text = CustomSegmentsStore.shared.raw

    let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
    tap.cancelsTouchesInView = false
    view.addGestureRecognizer(tap)
  }

  @IBAction private func customFieldChanged(_ sender: UITextField) {
    CustomSegmentsStore.shared.raw = sender.text ?? ""
    PiPSpeedController.shared.refresh()
  }

  @objc func applicationDidBecomeActive() {
    start()
    consumePendingPiPAction()
    syncPresetSelection()
  }

  // widget / 控制中心改档后回到 App, 让 segment 跟上 current.
  // segment 不需要触发 valueChanged, 直接改 selectedSegmentIndex 即可 (renderer 已被外部源更新).
  private func syncPresetSelection() {
    guard let presetControl else { return }
    if let idx = SpeedPreset.allCases.firstIndex(of: .current) {
      presetControl.selectedSegmentIndex = idx
    }
  }

  // 消费 widget 通过 App Group 留下的 PiP 指令 (start / stop). widget extension 进程
  // 不能直接调 PiPSpeedController, 走 openAppWhenRun + 标记 + 主 App 消费这条路.
  private func consumePendingPiPAction() {
    guard let action = AppGroup.defaults.string(forKey: PiPPendingAction.key) else { return }
    AppGroup.defaults.removeObject(forKey: PiPPendingAction.key)
    switch action {
    case PiPPendingAction.start:
      PiPSpeedController.shared.start()
    case PiPPendingAction.stop:
      PiPSpeedController.shared.stop()
    default:
      break
    }
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

  private func configureLayout() {
    shows.font = UIFont.monospacedSystemFont(ofSize: 28, weight: .regular)
    shows.textAlignment = .left

    let customRow = UIStackView(arrangedSubviews: [makeSectionLabel("custom"), customField])
    customRow.axis = .horizontal
    customRow.spacing = 12
    customRow.alignment = .center

    let presetControl = makePresetControl()
    self.presetControl = presetControl
    let sizeRow = UIStackView(arrangedSubviews: [makeSectionLabel("size"), presetControl])
    sizeRow.axis = .horizontal
    sizeRow.spacing = 12
    sizeRow.alignment = .center

    let startButton = makePiPButton(title: "Start PiP", action: #selector(startPiP))
    let stopButton = makePiPButton(title: "Stop PiP", action: #selector(stopPiP))
    let buttonRow = UIStackView(arrangedSubviews: [startButton, stopButton])
    buttonRow.axis = .horizontal
    buttonRow.spacing = 16
    buttonRow.distribution = .fillEqually

    // 控件整体上下居中, 顶部 / 底部都自适应留白; 自上而下: 网速 -> 输入框 -> 字号 -> Start/Stop.
    let mainStack = UIStackView(arrangedSubviews: [shows, customRow, sizeRow, buttonRow])
    mainStack.axis = .vertical
    mainStack.spacing = 16
    mainStack.alignment = .fill
    mainStack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(mainStack)

    NSLayoutConstraint.activate([
      mainStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
      mainStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
      mainStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor)
    ])
  }

  private func makeSectionLabel(_ text: String) -> UILabel {
    let label = UILabel()
    label.text = text
    label.font = .monospacedSystemFont(ofSize: 17, weight: .regular)
    label.textColor = .secondaryLabel
    label.widthAnchor.constraint(equalToConstant: 80).isActive = true
    return label
  }

  private func makePresetControl() -> UISegmentedControl {
    // 罗马 I..VI, 与桌面 widget 视觉保持一致, 不暴露 fontSize 物理值 (4..9).
    let titles = SpeedPreset.allCases.map { $0.displayLabel }
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
