#!/bin/sh
set -eu

ARCHIVE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-$ARCHIVE_DIR/.build}
OUTPUT_DIR=${OUTPUT_DIR:-$ARCHIVE_DIR/packages}
PACKAGE_VERSION=${KDEB_PKGVERSION:-}
SOURCE_DEB=$ARCHIVE_DIR/source/linux-source-7.0.0_7.0.0-29.29_all.deb
PATCH_FILE=$ARCHIVE_DIR/patches/drc-wxx-i915.patch
CONFIG_FILE=$ARCHIVE_DIR/config/kernel-7.0.12-drc-dsi1.config

BUILD_ID=$(
    sha256sum "$PATCH_FILE" "$CONFIG_FILE" |
        sha256sum |
        cut -c1-16
)
SOURCE_DIR=$WORK_ROOT/source-$BUILD_ID
BUILD_DIR=$WORK_ROOT/build-$BUILD_ID

extract_source() {
    temp_dir=$(mktemp -d "$WORK_ROOT/extract.XXXXXX")
    dpkg-deb -x "$SOURCE_DEB" "$temp_dir/pkg"
    mkdir -p "$SOURCE_DIR"
    tar -xjf "$temp_dir/pkg/usr/src/linux-source-7.0.0/linux-source-7.0.0.tar.bz2" \
        -C "$SOURCE_DIR" --strip-components=1
    rm -rf "$temp_dir"
}

if [ -z "$PACKAGE_VERSION" ]; then
    TAG=$(git -C "$ARCHIVE_DIR" describe --tags --exact-match 2>/dev/null || true)
    TAG_VERSION=${TAG#v}
    if printf '%s\n' "$TAG" | grep -Eq '^v[0-9]+([.][0-9]+)*$'; then
        PACKAGE_VERSION=$TAG_VERSION
    else
        PACKAGE_VERSION="0~local.$(date -u +%Y%m%d%H%M%S)"
    fi
fi

case "$PACKAGE_VERSION" in
    *[!0-9A-Za-z.+~:-]*|'')
        printf 'Invalid Debian package version: %s\n' "$PACKAGE_VERSION" >&2
        exit 1
        ;;
esac

if [ ! -f "$SOURCE_DEB" ]; then
    "$ARCHIVE_DIR/scripts/download-source.sh"
fi

mkdir -p "$WORK_ROOT"
if [ ! -d "$SOURCE_DIR/drivers/gpu/drm/i915/display" ]; then
    extract_source
    patch -d "$SOURCE_DIR" -p1 < "$PATCH_FILE"
fi

mkdir -p "$BUILD_DIR"
cp "$CONFIG_FILE" "$BUILD_DIR/.config"
make -C "$SOURCE_DIR" O="$BUILD_DIR" olddefconfig
make -C "$SOURCE_DIR" -j"$(nproc)" O="$BUILD_DIR" \
    KDEB_PKGVERSION="$PACKAGE_VERSION" bindeb-pkg

mkdir -p "$OUTPUT_DIR"
find "$WORK_ROOT" -maxdepth 1 -type f -name "*_${PACKAGE_VERSION}_amd64.deb" \
    -exec cp {} "$OUTPUT_DIR/" \;

if ! find "$OUTPUT_DIR" -maxdepth 1 -type f \
    -name "linux-image-*_${PACKAGE_VERSION}_amd64.deb" | grep -q .; then
    printf 'No linux-image package was produced for package version %s.\n' \
        "$PACKAGE_VERSION" >&2
    exit 1
fi

(cd "$OUTPUT_DIR" && sha256sum ./*_"$PACKAGE_VERSION"_amd64.deb > SHA256SUMS)
printf 'Build complete. Packages are in %s\n' "$OUTPUT_DIR"
