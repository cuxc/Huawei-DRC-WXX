# Huawei DRC-WXX 内屏修复内核

本仓库为 Huawei MateBook E（DMI：`HUAWEI` / `DRC-WXX`）构建带有 i915
内屏修复的 Ubuntu/Fedora 内核。仓库只保存当前补丁和构建配置；升级时直接
覆盖现有补丁，不在目录中并行保留多个版本。

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

## Ubuntu 安装

从 Actions artifact 或 Release 下载三个 `.deb` 包，在下载目录安装：

```bash
sudo dpkg -i \
  linux-image-7.0.12-drc-dsi1_*_amd64.deb \
  linux-headers-7.0.12-drc-dsi1_*_amd64.deb \
  linux-libc-dev_*_amd64.deb
```

其中 image 和 headers 用于内核安装；`linux-libc-dev` 是用户空间开发头文件，
不影响启动，但可以与前两个包一起安装。

补丁仅在 DMI 精确匹配 `HUAWEI` / `DRC-WXX` 时启用机型专用 workaround。完成后
重启，并在 GRUB 中选择 `7.0.12-drc-dsi1`。不要添加 `nomodeset`。DSB 已由补丁
在 i915 内部按 DMI 处理，不需要额外
的 `i915.enable_dsb=0` 启动参数。

## Fedora 安装

从 Actions 的 `huawei-drc-wxx-kernel-fedora` artifact 或 Release 下载 RPM，
在下载目录安装内核；`kernel-devel` 用于 akmods/DKMS 等外部模块：

```bash
sudo dnf install \
  ./kernel-7.0.12_drc_dsi1-*.x86_64.rpm \
  ./kernel-devel-7.0.12_drc_dsi1-*.x86_64.rpm
```

`kernel-headers` 是可选的用户空间开发头文件，不影响启动。安装后重启，从
GRUB 选择 `7.0.12-drc-dsi1`。不要添加 `nomodeset` 或
`i915.enable_dsb=0`。

该内核没有使用 Fedora 官方 Secure Boot 密钥签名。启用了 Secure Boot 的
设备需要先关闭 Secure Boot，或自行签名并登记密钥，否则固件/引导器可能拒绝
加载内核或模块。

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

## 致谢

感谢 [Linux.do](https://linux.do) 的 token 支持
