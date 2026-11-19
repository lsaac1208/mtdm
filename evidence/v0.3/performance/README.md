# macOS 实机帧时间

2026-11-19，Mac mini（Apple M6，12 核 GPU，32 GB 统一内存），macOS 27.2.1（26B131），Godot 4.7.2.stable.official.ed1daf0bf。主显示器为 1920×1080、120 Hz，另接一台 1920×1080、60 Hz 显示器。游戏以 1280×720 窗口运行，使用常规难度。每个场景用独立进程依次运行。

## 测量结果

下表为源码在真实设备上渲染时，相邻两次 `RenderingServer.frame_post_draw` 回调之间的墙钟间隔，单位为毫秒。比较组使用 `--max-fps 60` 实时限速，物理模拟每秒 60 次；项目的垂直同步设定为开启。回调间隔包含主机调度与等待，显示器实际显示一帧的时刻未单独采集。

| 渲染配置 | 实际回放 | 帧间隔样本数 | P50 | P95 | P99 | 日志 |
|---|---|---:|---:|---:|---:|---|
| 发布默认，OpenGL 4.1 / Compatibility | 埋骨地混战 | 529 | 16.71 | 19.59 | 23.36 | [完整记录](gl_compatibility-wave.log) |
| 发布默认，OpenGL 4.1 / Compatibility | 尸将 | 409 | 16.73 | 19.00 | 20.79 | [完整记录](gl_compatibility-elite.log) |
| 补充配置，原生 Metal 4.0 / Forward Mobile | 埋骨地混战 | 523 | 16.76 | 19.23 | 22.45 | [完整记录](mobile-wave.log) |
| 补充配置，原生 Metal 4.0 / Forward Mobile | 尸将 | 410 | 16.72 | 18.92 | 20.26 | [完整记录](mobile-elite.log) |

默认项目没有额外的 FPS 上限。移除 60 FPS 限速后，OpenGL 混战的 3066 个回调间隔为 2.99 / 4.67 / 5.24 ms（P50/P95/P99）。该采样可复核渲染循环在此机器上的运行速度。尸将的未限速复测多次遇到只使用横扫的战斗序列，现有回放要求捕获举刀帧，未产出完整统计；表中采用成功捕获重劈的限速回放。[未限速混战](gl_compatibility-wave-uncapped.log) · [未命中举刀镜头的尸将记录](uncapped-elite-no-chop.log)

**GPU 执行时长未测得。** 两种后端均已调用 `viewport_set_measure_render_time`，它们返回的 GPU 时间均无有效正值。另启 Godot 的 `--gpu-profile`，两场景、两后端报告的 GPU 总时间均为 0.0 ms。此处将 GPU 百分位数标为缺测。发布版的帧间隔与原生 Metal 补测使用各自的驱动记录。[GPU 计数器复核](gpu-counter-check.log)

## 复跑

从仓库根目录运行；将 `wave` 换为 `elite` 即可复核尸将。脚本按固定输入加载真实关卡，并在该次交战中读取屏幕图像一次。采样使用正常时间推进，包含截图发生的帧。普通试玩的帧时间会随设备、镜头、分辨率与战况变化。

```sh
profile_dir=$(mktemp -d)
godot --path game --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1280x720 --single-window --position 80,80 --max-fps 60 \
  -- --test=visual_replay --scene=wave --measure --difficulty=1 \
  --qa-settings="$profile_dir/settings.cfg" --evidence="$profile_dir"
```

原生 Metal 补测使用 `--rendering-method mobile --rendering-driver metal`。移除 `--max-fps 60` 可复跑项目默认帧率设定。[回放与计时实现](../../../game/tests/visual_review.gd)
