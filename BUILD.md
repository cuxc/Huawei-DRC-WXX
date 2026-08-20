# 构建和发布

## GitHub Actions

大文件不提交到 GitHub：原始 Ubuntu 内核源码包由 Action 在构建时下载，编译
产生的 `.deb` 只作为 Actions artifact 或 GitHub Release 附件保存。

Action 会：

1. 从 Ubuntu 官方归档下载固定版本的 `linux-source-7.0.0` 源码包并校验 SHA-256。
2. 应用 `patches/drc-wxx-i915.patch` 和 `config/` 中的配置。
3. 构建 image、headers、libc-dev 包及 `SHA256SUMS`。
4. 普通分支构建使用 `0~ci.<run>.<attempt>` 测试版本并上传 artifact。
5. 标签构建从 Git tag 自动取得正式包版本并创建 GitHub Release。

首次推送：

```bash
git add .
git commit -m "Build kernel packages in GitHub Actions"
git push origin main
```

先在 Actions 页面下载并验证 `huawei-drc-wxx-kernel` artifact。确认无误后，为
当前提交创建正式标签。标签格式必须是 `v` 加数字版本，例如 `v4` 或 `v5.1`：

```bash
git tag v4
git push origin v4
```

`v4` 会生成 Debian 包版本 `4`，并创建 `v4` Release。以后升级时，覆盖当前
补丁并提交，然后创建新的标签即可。

## 本地构建

在 Ubuntu 上安装依赖：

```bash
sudo apt-get update
sudo apt-get install -y bc binutils bison build-essential cpio debhelper \
  dpkg-dev dwarves fakeroot flex kmod libdw-dev libelf-dev libncurses-dev \
  libssl-dev python3 rsync xz-utils zstd
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

安装和诊断说明见 [README.md](README.md)。
