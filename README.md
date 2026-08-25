# Huawei DRC-WXX 内屏修复内核

本仓库为 Huawei MateBook E（DMI：`HUAWEI` / `DRC-WXX`）构建带有 i915
内屏修复的 Ubuntu/Fedora 内核。仓库只保存当前补丁和构建配置；升级时直接
覆盖现有补丁，不在目录中并行保留多个版本。

构建、GitHub Actions 和 Release 使用方法见 [BUILD.md](BUILD.md)。

## 当前修复

补丁在 DMI 精确匹配 `HUAWEI` / `DRC-WXX` 时自动启用：

- 为双链路 DSI 命令模式正确写入和读取 `TRANS_HSYNC`。
- 修正双链路面板的 TE pin 判断。
- 驱动接管时执行 VBT GPIO、电源、复位和 DCS 初始化，不依赖 BIOS 残留状态。
- 对双链路命令模式强制完整 modeset，而不是沿用固件状态做 fastset。
- 自动关闭 DSB。
- 关闭 DSI transcoder 前先停止命令模式周期更新。
- 改善 DSI transcoder 关闭超时日志，记录具体 transcoder 和端口。

设计原则是开机和唤醒走同一条路。早期版本跳过了 VBT GPIO 和 initial display
commit，开机时可以借用 BIOS 已经点亮的状态，但挂起后显示电源域和 DSI link
状态会被清空，唤醒时面板无法重新上电，表现为键盘已恢复而内屏仍黑屏。当前
补丁让驱动完整接管面板生命周期，避免依赖 BIOS 保存寄存器状态。

## 验证

workaround 生效时应能看到：

```text
Applying Huawei DRC-WXX dual-link DSI workaround (DSB disabled)
```

开启 KMS 调试后还应看到 `Forcing full modeset for dual-link command-mode DSI`；
该行是 debug 级别日志，默认可能不会显示。

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
时序不匹配警告。只要画面正常，不要为消除这些警告修改面板时序。修复后的
suspend/resume 路径需要在实机上验证开机、息屏、`systemctl suspend` 和合盖四种
场景；如果唤醒后仍黑屏，请按下面流程抓取日志。

## 唤醒黑屏诊断

黑屏时机器通常仍在运行。安装一次诊断钩子，让 journald 持久化并在唤醒后保存
内核日志：

```bash
sudo ./scripts/sleep-debug.sh install
systemctl suspend
# 唤醒后如果屏幕仍黑，可按 Alt+SysRq+S，再按 Alt+SysRq+B 重启
sudo ./scripts/sleep-debug.sh collect
```

收集的压缩日志包会写在当前目录。重点查看 `GPIO index`、`ULPS`、`not disabled`、
`not idle`、`Restoring old state` 和 `i915.*ERROR`。诊断完成后可还原钩子：

```bash
sudo ./scripts/sleep-debug.sh uninstall
```

如果新内核启动后就黑屏，可以在 GRUB 的 Advanced options 中选择旧内核回退；
安装前请至少保留一个可启动的旧内核。

## 致谢

感谢 [Linux.do](https://linux.do) 的 token 支持
