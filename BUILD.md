# 构建和发布

## GitHub Actions

大文件不提交到 GitHub：原始 Ubuntu 内核源码包由 Action 在构建时下载，编译
产生的 `.deb` 和 `.rpm` 只作为 Actions artifact 或 GitHub Release 附件保存。

Action 会：

1. 从 Ubuntu 官方归档下载固定版本的 `linux-source-7.0.0` 源码包并校验 SHA-256。
2. 在 Ubuntu 24.04 和 Fedora 43 环境中应用补丁和 `config/` 中的配置。
3. 分别构建 Debian image/headers/libc-dev 包、Fedora kernel/devel/headers 包及
   `SHA256SUMS.deb` / `SHA256SUMS.rpm`。
4. Debian 普通分支构建使用 `0~ci.<run>.<attempt>` 测试版本；Fedora RPM 使用
   Actions run number 作为 release。
5. 标签构建从 Git tag 取得 Debian 包版本，并把两种格式发布到 GitHub Release。

首次推送：

```bash
git add .
git commit -m "Build kernel packages in GitHub Actions"
git push origin main
```

先在 Actions 页面下载并验证 `huawei-drc-wxx-kernel` 和
`huawei-drc-wxx-kernel-fedora` artifact。确认无误后，为当前提交创建正式标签。
标签格式必须是 `v` 加数字版本，例如 `v4` 或 `v5.1`：

```bash
git tag v4
git push origin v4
```

`v4` 会生成 Debian 包版本 `4`，并创建 `v4` Release。以后升级时，覆盖当前
补丁并提交，然后创建新的标签即可。

## Ubuntu 本地构建

在 Ubuntu 上安装依赖：

```bash
sudo apt-get update
sudo apt-get install -y bc binutils bison build-essential bzip2 cpio curl \
  debhelper dpkg-dev dwarves fakeroot flex kmod libdw-dev libelf-dev \
  libncurses-dev libssl-dev patch python3 rsync xz-utils zstd
```

然后运行：

```bash
./scripts/rebuild.sh
```

如果当前提交恰好带有 `v<数字>` 标签，本地构建会采用该标签版本；否则生成
`0~local.<时间>` 测试版本。也可以显式指定：

```bash
KDEB_PKGVERSION=4 ./scripts/rebuild.sh
```

源码包、构建目录和 `.deb` 均已由 `.gitignore` 排除，不会被误提交。

## Fedora 本地构建

在 Fedora 43 上安装依赖：

```bash
sudo dnf install -y bc binutils bison bzip2 cpio curl diffutils dwarves \
  elfutils-devel elfutils-libelf-devel findutils flex gcc git gzip \
  hostname kmod make ncurses-devel openssl openssl-devel patch perl python3 \
  rpm-build rsync tar xz zstd
```

然后运行：

```bash
./scripts/rebuild.sh
```

脚本会从 `/etc/os-release` 自动选择 RPM 构建，也可显式指定
`PACKAGE_FORMAT=rpm`。未指定 release 时，非数字版本默认使用 UTC 时间戳；需要
固定 release 时可指定正整数：

```bash
RPM_PACKAGE_RELEASE=4 ./scripts/rebuild.sh
```

RPM 输出到 `packages/`，包括启动所需的 `kernel`、构建外部模块所需的
`kernel-devel`，以及可选的 `kernel-headers`。RPM 和构建目录均已由
`.gitignore` 排除。

安装和诊断说明见 [README.md](README.md)。
