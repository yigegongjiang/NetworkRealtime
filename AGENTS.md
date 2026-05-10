# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

iOS app，在 Picture-in-Picture（画中画）浮窗实时显示网络上传/下载速度。基于 UIKit + AVKit 构建。

仅能在真机上运行（PiP 自定义内容不能在 simulator 启动；依赖 `getifaddrs` 系统调用）。

## Architecture

### 数据流

```
getifaddrs (系统调用)
  → NetworkSpeedMonitor (每秒轮询，计算差值得出速率)
    → PiPSpeedController.update(uText:dText:)
      → SpeedFrameRenderer (UIImage → CVPixelBuffer → CMSampleBuffer)
        → AVSampleBufferDisplayLayer.enqueue
          → AVPictureInPictureController (浮窗展示)
```

### 后台保活

`LocationManager` 通过持续请求位置更新实现后台保活（`allowsBackgroundLocationUpdates = true`），使 `NetworkSpeedMonitor` 的定时器能在后台持续运行。Info.plist 中声明了 `location`、`fetch`、`processing`、`audio` 四种 background mode。

`audio` 是 PiP 必需（`AVAudioSession.playback` 必须 active），不真发声。

### Target

只有 `Speedo` 一个 App target（UIKit，`@main AppDelegate`）。

### 依赖（SPM）

- `swift-log` — Apple 官方日志抽象
- `swift-log-syslog` — syslog 后端

### 关键设计细节

- `NetworkSpeedMonitor.getNetworkBytes()` 通过 `getifaddrs` 遍历网络接口，仅统计 `en`/`pdp_ip`/`rmnet`/`ppp`/`wwan` 前缀的接口
- 速率单位自动换挡：`b`（bytes）→ `k`（KB）→ `m`（MB）
- 检测到字节计数回退（设备重启等）时会重置基准值，跳过该轮计算
- `AppDelegate.didFinishLaunching` 配置 `AVAudioSession(.playback, .mixWithOthers)` 并 `setActive(true)`，是 PiP 启动的前置条件
- `PiPSpeedController.attach(to:)` 把 `displayLayer` 挂入视图树并 enqueue 一帧 placeholder（PiP 启动要求 layer 已有内容且 bounds 非零）
- 所有 Manager 均为单例模式（`static let shared`）
