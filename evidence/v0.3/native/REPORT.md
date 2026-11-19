# 0.3.0 RC1 · 原生包验收

候选标签为 `v0.3.0-rc.1`，三份压缩包来自游戏源提交 `93cee6d`。测试先核对 GitHub 发布资产的 SHA-256，再将 ZIP 解压到新目录。每个测试进程使用独立设置文件。

| 系统 | 引擎检查 | 输入机器人通过常规难度全程 | 标题与荒村实际渲染 |
| --- | --- | --- | --- |
| Mac mini · Apple M6 | 52/52 | 通过 | 通过 |
| macOS 15 · Apple Silicon 虚拟设备 | 52/52 | 通过 | 通过 |
| Ubuntu 24.04 x64 · Mesa | 52/52 | 通过 | 通过 |
| Windows Server 2025 x64 | 52/52 | 通过 | 默认启动通过 |
| Windows Server 2022 x64 | 见 2025 同包检查 | 见 2025 同包检查 | 默认启动通过 |

本机 M6 使用通过 Launch Services 实际打开的解压版。应用临时签名校验通过，主程序包含 arm64 和 x86_64；Intel Mac 运行与 Apple 公证另行记录。Linux 包另外连续通关两次，节点始终为 38，孤立对象始终为 0。Windows 与 Linux 托管环境使用各自的软件图形设备。两个 Windows 桌面均从原样解压的 EXE 启动，Godot 自动选用 ANGLE / Direct3D 11，标题与首战均生成实机 PNG 并正常退出。托管桌面返回的实际窗口为 1028×720。首轮测试曾强制指定 WGL 并加入本地 Mesa DLL，该诊断路径无法创建窗口，原始失败记录保留在 JSON 的 `windows` 项。玩家默认启动的复测保存在 `windows-player-default` 项。

## 图形环境

- **Mac mini · Apple M6**　OpenGL API 4.1 Metal - 91.7 - Compatibility - Using Device: Apple - Apple M6
- **macOS 15 · Apple Silicon 虚拟设备**　OpenGL API OpenGL ES 3.0 (ANGLE 2.1.1 git hash: aaebda1c5a40) - Compatibility - Using Device: Google Inc. (Apple) - ANGLE (Apple, ANGLE Metal Renderer: Apple Paravirtual device, Version 15.8.2 (Build 24H232))
- **Ubuntu 24.04 x64 · Mesa**　OpenGL API 4.5 (Core Profile) Mesa 25.2.8-0ubuntu0.24.04.5 - Compatibility - Using Device: Mesa - llvmpipe (LLVM 20.1.2, 256 bits)
- **Windows Server 2022 / 2025 x64**　Godot 自动选用 ANGLE，设备为 Microsoft Basic Render Driver，使用 Direct3D 11。

[Windows 默认窗口复测与原始截图](https://github.com/lsaac1208/mtdm/actions/runs/44461394261) · [三平台下载包首轮验证](https://github.com/lsaac1208/mtdm/actions/runs/44458758509) · [机器可读测试结果](results.json) · [Apple M6 游戏帧时间及 GPU 计时](../performance/README.md) · [首次玩家记录](../PLAYTEST.md)
