# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 版本号遵循 [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-05-10

### Added

- 主页自定义文字输入框, 支持 `,` 与 `，` 切分多段, 实时附加在 PiP 浮窗网速之后
- `CustomSegmentsStore` (单例 + UserDefaults) 持久化用户原始字符串
- `PiPSpeedController.refresh()` 用最近一帧网速文本立即重推, 自定义文字变更 / 字号切换无需等下一秒回调

### Changed

- `SpeedFrameRenderer.render` 接口由 `(uText, dText)` 重构为 `segments: [String]`, 渲染层与数据来源解耦, 由 `PiPSpeedController` 负责拼装 `["↑u", "↓d"] + custom`
- 主页布局重写为栈式 (网速 / custom / size / Start-Stop), 整体贴底部 safeArea, 顶部留白; 点击空白收键盘
- 默认 Run scheme 由 Debug 切为 Release

### Removed

- 残留的 `LiveActivityWidgetExtension.xcscheme` (PiP 替换 Live Activity 后未清理的 scheme 配置)
