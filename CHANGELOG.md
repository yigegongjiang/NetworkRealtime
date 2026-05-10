# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 版本号遵循 [SemVer](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-05-10

### Added

- 新 Widget Extension `SpeedoWidgets` (systemSmall 2x2): 6 档字号按钮 (罗马 I-VI) + 4 动作按钮 (Start / Stop PiP, toggle 最近两档, 打开 App)
- App Group `group.jp.elestyle.Speedo` 共享 `SpeedPreset` / `CustomSegments` (主 App ↔ Widget)
- `Shared/` 目录承载双 target 共用文件: `AppGroup`, `AppLaunchIntents`, `SpeedPreset`, `CustomSegmentsStore`
- `SpeedPreset.previous` / `switchTo` / `broadcastChange`: 维护"上一档"快照供 widget toggle, 任意改档统一 reload timeline

### Changed

- 主 App segment 标签由 `4..9` 改为罗马 `I..VI`, 与 widget 视觉一致, 不暴露物理 fontSize
- 主页布局由贴底部 safeArea 改为上下居中, 顶/底自适应留白
- `PiPSpeedController.update` 每秒比对 `SpeedPreset.current`, 检测到跨进程改档自动同步 `renderer.preset`, 不依赖 Darwin notification
- `applicationDidBecomeActive` 消费 widget 通过 App Group 留下的 PiP 指令 (start / stop), 并把 segment 选中同步到 `current`
- `SpeedPreset` / `CustomSegmentsStore` 存储后端从 `UserDefaults.standard` 迁到 `AppGroup.defaults`
- `OpenAppIntent` / `StartPiPIntent` / `StopPiPIntent` 双 target 编译: 主 App 进程也需 AppIntent metadata, 否则 widget tap 拉起主 App 后 perform 不会被 dispatch
- 项目整体由 `NetworkRealtime` 重命名为 `Speedo` (Xcode project / App target / Widget target / Bundle ID / App Group / 仓库 README)

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
