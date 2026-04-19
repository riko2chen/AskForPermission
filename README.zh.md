# AskForPermission

[English](README.md) · [中文](README.zh.md)

一个 macOS Swift 包，为 macOS TCC 权限提供引导流程：打开正确的系统设置页面，在设置窗口旁浮一张指引卡，让用户把宿主 app 的图标拖进权限列表。

适合需要通过「把 app 拖进列表」完成授权的 macOS app 开发者。

https://github.com/user-attachments/assets/8360c7a3-2546-4f8c-92d7-247ae460f5ce

![演示](docs/assets/demo.gif)

## 支持范围

系统设置「隐私与安全性」下任何采用「把 app 拖进列表」交互的面板：

| 权限 | `PermissionKind` |
|---|---|
| Accessibility | `.accessibility` |
| Screen & System Audio Recording | `.screenRecording` |
| Input Monitoring | `.inputMonitoring` |
| Full Disk Access | `.fullDiskAccess` |
| Developer Tools | `.developerTools` |
| App Management | `.appManagement` |

授权检测机制和不在范围内的权限见 [`docs/architecture.md`](docs/architecture.md#supported-permissions)（英文）。

## 和 Codex Computer Use 的对照

视觉和交互沿用 Codex Computer Use 的权限引导体验。实现层面有几处取舍不同。

**相同点**

- 卡片从按钮位置飞出，贴靠系统设置窗口
- 卡片上有可拖拽的 app 图标，拖进列表完成授权
- 落位时欠阻尼的回弹弹簧，卡片和箭头会越过再回来
- 卡片跟随用户拖动的系统设置窗口
- 在台前调度下正常工作

**不同点**

- 飞行：单 `NSPanel` 加 layered `CALayer` 交叉淡入
- 路径：显式的二次贝塞尔抛物线，顶点高度固定为 160pt
- 飞行两端无视觉空档（replicant 就位后源行才翻到 dashed 态）
- 系统设置关闭或从 Dock 复原时，会等窗口 frame 稳定后再计算目标位置

## 如何运行示例仓库

clone 下来后，仓库自带一个 example app，在一个带 tab 的窗口里演示每一种接入方式（内置窗口 / SwiftUI / AppKit）。

```bash
git clone https://github.com/riko2chen/AskForPermission.git
cd AskForPermission
./Examples/AskForPermissionExample/build.sh
open Examples/AskForPermissionExample/build/AskForPermissionExample.app
```

环境要求：macOS 13+、Xcode 15+（提供 Swift 5.9 工具链）。构建脚本会在 `Examples/AskForPermissionExample/build/` 下产出一个已签名的 `.app`，不需要 Xcode 工程。

反复测试时重置 TCC 授权：

```bash
tccutil reset All com.example.askforpermission.example
killall AskForPermissionExample 2>/dev/null
```

## 最简接入

```swift
import AppKit
import AskForPermission

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NSWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AskForPermission.configure(appName: "My App")
        controller = AskForPermission.permissionsWindowController()
        controller?.showWindow(nil)
    }
}
```

这一段直接把内置的权限列表窗口放进 app 里。SwiftUI 宿主可以直接用 `PermissionsView`，或者在自己的按钮上挂 `.requestsPermission(_:)` / `.askForPermission(item:)`。AppKit 下想从某个按钮触发单个权限的请求，用 `AskForPermission.request(_:from: NSButton)`。完整 API 看 [docs/api.md](docs/api.md)。

## 文档

- [架构与请求流程](docs/architecture.md)
- [公共 API 参考](docs/api.md)
- [安装、示例与开发](docs/integration.md)

## 许可证

MIT。
