# Huawei DRC-WXX 内屏修复内核

本仓库为 Huawei MateBook E（DMI：`HUAWEI` / `DRC-WXX`）构建带有 i915
内屏修复的 Ubuntu 内核。仓库只保存当前补丁和构建配置；升级时直接覆盖现有
补丁，不在目录中并行保留多个版本。

构建、GitHub Actions 和 Release 使用方法见 [BUILD.md](BUILD.md)。

## 当前修复

补丁在 DMI 精确匹配 `HUAWEI` / `DRC-WXX` 时自动启用：

- 为双链路 DSI 命令模式正确写入和读取 `TRANS_HSYNC`。
- 修正双链路面板的 TE pin 判断。
- 跳过该机型不兼容的 VBT GPIO 操作。
- 跳过会破坏 BIOS 已初始化状态的 initial display commit。
- 自动关闭 DSB，并允许该机型沿用固件状态进行 initial fastset。
- 关闭 DSI transcoder 前先停止命令模式周期更新。
- 改善 DSI transcoder 关闭超时日志，记录具体 transcoder 和端口。

## 其他机器试用

安装包不限制机器型号。其他可能存在类似双链路 DSI 问题的机器需要显式添加：

```text
i915.force_drc_wxx_workaround=1
```

该参数默认关闭，因此 DRC-WXX 专用的 DSB、VBT GPIO 和 initial display commit
行为不会在其他机器上自动启用。不过补丁中的通用双链路 DSI 时序修正会对相应
的 DSI 控制器生效；强制参数还会跳过部分显示初始化，可能导致黑屏。建议先通过
GRUB 临时添加，确认可用后再持久化。

## 验证

workaround 生效时应能看到：

```text
Applying Huawei DRC-WXX dual-link DSI workaround (DSB disabled)
Skipping initial display commit for Huawei DRC-WXX
```

诊断命令：

```bash
./scripts/diagnose.sh
```

## 安装

从 Actions artifact 或 Release 下载三个 `.deb` 包，在下载目录安装：

```bash
sudo dpkg -i \
  linux-image-7.0.12-drc-dsi1_*_amd64.deb \
  linux-headers-7.0.12-drc-dsi1_*_amd64.deb \
  linux-libc-dev_*_amd64.deb
```

其中 image 和 headers 用于内核安装；`linux-libc-dev` 是用户空间开发头文件，
不影响启动，但可以与前两个包一起安装。

安装不限制机器型号。完成后重启，并在 GRUB 中选择 `7.0.12-drc-dsi1`。不要
添加 `nomodeset`。DSB 已由补丁在 i915 内部按 DMI/强制参数处理，不需要额外
的 `i915.enable_dsb=0` 启动参数。

## 已知问题

日志仍可能出现 `pipe state doesn't match` 或 `hw.pipe_mode` / `adjusted_mode`
时序不匹配警告。只要画面正常，不要为消除这些警告修改面板时序。当前 DSI
suspend/resume 路径也尚未完全修好，合盖进入 `s2idle` 后可能黑屏。

## 合盖黑屏的临时规避

普通锁屏（`Super+L`）不进入 `s2idle`。如果合盖唤醒后出现黑屏，可以暂时将
合盖动作改为只锁屏：

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudoedit /etc/systemd/logind.conf.d/90-drc-wxx-lid.conf
```

写入：

```ini
[Login]
HandleLidSwitch=lock
HandleLidSwitchExternalPower=lock
```

保存后重启系统使配置生效。这只能避免合盖时进入 `s2idle`，不是 DSI
suspend/resume 黑屏问题的内核修复。安装新版本后可以先临时执行
`systemctl suspend` 测试唤醒，再决定是否恢复默认合盖动作。
