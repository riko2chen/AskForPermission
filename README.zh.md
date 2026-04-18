# AskForPermission

[English](README.md) · [中文](README.zh.md)

一个 macOS Swift 包，为 Accessibility 和 Screen Recording 两项 TCC 权限提供精致的引导流程：打开正确的系统设置页面，在设置窗口旁浮一张指引卡，让用户把宿主 app 的图标拖进权限列表。

适合需要这两项权限的 macOS app 开发者。

![演示](docs/assets/demo.gif)

## 和 Codex Computer Use 的对照

在视觉和交互上对齐 Codex Computer Use 的权限引导体验。实现层面在几个点上做了不同的取舍。

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

## 最简接入

```swift
import AppKit
import AskForPermission

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var center: PermissionCenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = try? PermissionCenter(appName: "My App")
        self.center = center
        center?.makePermissionsWindow().makeKeyAndOrderFront(nil)
    }
}
```

这一段直接把内置的权限列表窗口放进 app 里。如果只想从某个按钮触发单个权限的请求，看 [docs/api.md](docs/api.md)。

## 文档

- [架构与请求流程](docs/architecture.md)
- [公共 API 参考](docs/api.md)
- [安装、示例与开发](docs/integration.md)

## 许可证

MIT。
