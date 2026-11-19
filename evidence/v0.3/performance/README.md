# macOS 实机帧时间

2026-11-19，Mac mini（Apple M6，12 核 GPU，32 GB 统一内存），macOS 27.2.1（26B131），Godot 4.7.2.stable.official.ed1daf0bf。主显示器为 1920×1080、120 Hz，另接一台 1920×1080、60 Hz 显示器。游戏以 1280×720 窗口运行，使用常规难度。每个场景用独立进程依次运行。

## GPU 实际执行时间

发布默认的 OpenGL Compatibility 渲染路径接受原生 `GL_TIME_ELAPSED` 查询（32 位计数精度）。在隔离的候选工程副本中，通过 Godot 渲染线程对 `frame_pre_draw` 和 `frame_post_draw` 夹住的 GPU 命令计时。每帧延迟回读硬件结果，测量结束后一次性输出。两次均未跳过或拒收查询，也未发生 OpenGL 上下文切换。除临时诊断 autoload、扩展及其配置以外，原工程所有运行文件均已核对一致。扩展源码保存在验收目录。

| 场景 | 完整 GPU 样本 | GPU P50 | GPU P95 | GPU P99 | 原始逐帧数据和同时采集的墙钟间隔 |
|---|---:|---:|---:|---:|---|
| 埋骨地混战 | 527 | 5.339 ms | 8.696 ms | 9.241 ms | [混战原始记录](gl-wave-native.log) |
| 尸将战 | 409 | 6.702 ms | 7.393 ms | 7.738 ms | [尸将原始记录](gl-elite-native.log) |

两场均在 1280×720、实时限速 60 FPS 下完成。以上数值代表这台 Mac 上 GPU 执行一帧 OpenGL 命令所跨过的时间。真实操作到画面显示的延迟还包括输入、CPU、显示合成与扫描输出。

## 实际渲染回调间隔

下表为源码在真实设备上渲染时，相邻两次 `RenderingServer.frame_post_draw` 回调之间的墙钟间隔，单位为毫秒。比较组使用 `--max-fps 60` 实时限速，物理模拟每秒 60 次；项目的垂直同步设定为开启。回调间隔包含主机调度与等待，显示器实际显示一帧的时刻未单独采集。

| 渲染配置 | 实际回放 | 帧间隔样本数 | P50 | P95 | P99 | 日志 |
|---|---|---:|---:|---:|---:|---|
| 发布默认，OpenGL 4.1 / Compatibility | 埋骨地混战 | 529 | 16.71 | 19.59 | 23.36 | [完整记录](gl_compatibility-wave.log) |
| 发布默认，OpenGL 4.1 / Compatibility | 尸将 | 409 | 16.73 | 19.00 | 20.79 | [完整记录](gl_compatibility-elite.log) |
| 补充配置，原生 Metal 4.0 / Forward Mobile | 埋骨地混战 | 523 | 16.76 | 19.23 | 22.45 | [完整记录](mobile-wave.log) |
| 补充配置，原生 Metal 4.0 / Forward Mobile | 尸将 | 410 | 16.72 | 18.92 | 20.26 | [完整记录](mobile-elite.log) |

默认项目没有额外的 FPS 上限。移除 60 FPS 限速后，OpenGL 混战的 3066 个回调间隔为 2.99 / 4.67 / 5.24 ms（P50/P95/P99）。该采样可复核渲染循环在此机器上的运行速度。尸将的未限速复测多次遇到只使用横扫的战斗序列，现有回放要求捕获举刀帧，未产出完整统计；表中采用成功捕获重劈的限速回放。[未限速混战](gl_compatibility-wave-uncapped.log) · [未命中举刀镜头的尸将记录](uncapped-elite-no-chop.log)

两种后端的 Godot 视口计数器均无有效 GPU 时间，另启 `--gpu-profile` 也只记录到 0.0 ms。原生 Metal 后端在 Godot 4.7.2 中将时间查询结果清零，Metal 补测仅报告渲染回调间隔。上面的 GPU 表来自 OpenGL 驱动的独立查询。[GPU 计数器复核](gpu-counter-check.log) · [Godot 4.7.2 Metal 时间查询实现](https://github.com/godotengine/godot/blob/4.7.2-stable/drivers/metal/rendering_device_driver_metal.cpp#L2342-L2355)

## 复跑

复核 GPU 时间，在 Apple Silicon Mac 从仓库运行 `evidence/v0.3/performance/probe/measure.sh /path/to/results`。它在临时工程中构建诊断扩展，输出两场逐帧日志和截图。[独立测量脚本](probe/measure.sh) · [原生查询源码](probe/gpu_probe.cpp)

复核渲染回调间隔，从仓库根目录运行以下命令。将 `wave` 换为 `elite` 即可复核尸将。脚本按固定输入加载真实关卡，并在该次交战中读取屏幕图像一次。采样使用正常时间推进，包含截图发生的帧。普通试玩的帧时间会随设备、镜头、分辨率与战况变化。

```sh
profile_dir=$(mktemp -d)
godot --path game --rendering-method gl_compatibility --rendering-driver opengl3 \
  --resolution 1280x720 --single-window --position 80,80 --max-fps 60 \
  -- --test=visual_replay --scene=wave --measure --difficulty=1 \
  --qa-settings="$profile_dir/settings.cfg" --evidence="$profile_dir"
```

原生 Metal 补测使用 `--rendering-method mobile --rendering-driver metal`。移除 `--max-fps 60` 可复跑项目默认帧率设定。[回放与计时实现](../../../game/tests/visual_review.gd)
