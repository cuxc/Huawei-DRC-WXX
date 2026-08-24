#!/bin/sh
set -eu

ARCHIVE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK_ROOT=${WORK_ROOT:-$ARCHIVE_DIR/.build}
OUTPUT_DIR=${OUTPUT_DIR:-$ARCHIVE_DIR/packages}
PACKAGE_FORMAT=${PACKAGE_FORMAT:-auto}
PACKAGE_VERSION=${PACKAGE_VERSION:-${KDEB_PKGVERSION:-}}
RPM_PACKAGE_RELEASE=${RPM_PACKAGE_RELEASE:-}
CHECKSUM_FILE=${CHECKSUM_FILE:-SHA256SUMS}
SOURCE_DEB=$ARCHIVE_DIR/source/linux-source-7.0.0_7.0.0-29.29_all.deb
PATCH_FILE=$ARCHIVE_DIR/patches/drc-wxx-i915.patch
CONFIG_FILE=$ARCHIVE_DIR/config/kernel-7.0.12-drc-dsi1.config

BUILD_ID=$(
    sha256sum "$PATCH_FILE" "$CONFIG_FILE" |
        sha256sum |
        cut -c1-16
)
SOURCE_DIR=$WORK_ROOT/source-$BUILD_ID

detect_package_format() {
    if [ -r /etc/os-release ]; then
        # os-release is defined as shell-compatible key/value assignments.
        ID=
        ID_LIKE=
        . /etc/os-release
        case "${ID:-} ${ID_LIKE:-}" in
            *fedora*|*rhel*) printf '%s\n' rpm; return ;;
            *debian*|*ubuntu*) printf '%s\n' deb; return ;;
        esac
    fi

    if command -v rpmbuild >/dev/null 2>&1 &&
        ! command -v dpkg-buildpackage >/dev/null 2>&1; then
        printf '%s\n' rpm
    else
        printf '%s\n' deb
    fi
}

case "$PACKAGE_FORMAT" in
    auto) PACKAGE_FORMAT=$(detect_package_format) ;;
    deb|rpm) ;;
    *)
        printf 'Unsupported package format: %s (expected auto, deb, or rpm)\n' \
            "$PACKAGE_FORMAT" >&2
        exit 1
        ;;
esac

BUILD_DIR=$WORK_ROOT/build-$BUILD_ID-$PACKAGE_FORMAT

extract_source() {
    temp_dir=$(mktemp -d "$WORK_ROOT/extract.XXXXXX")
    mkdir -p "$temp_dir/deb" "$temp_dir/pkg"
    data_member=$(ar t "$SOURCE_DEB" | sed -n '/^data[.]tar/ { p; q; }')
    if [ -z "$data_member" ]; then
        printf 'No data archive found in %s.\n' "$SOURCE_DEB" >&2
        rm -rf "$temp_dir"
        exit 1
    fi
    (cd "$temp_dir/deb" && ar x "$SOURCE_DEB" "$data_member")
    tar -xf "$temp_dir/deb/$data_member" -C "$temp_dir/pkg"
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

if [ "$PACKAGE_FORMAT" = deb ]; then
    case "$PACKAGE_VERSION" in
        *[!0-9A-Za-z.+~:-]*|'')
            printf 'Invalid Debian package version: %s\n' "$PACKAGE_VERSION" >&2
            exit 1
            ;;
    esac
else
    if [ -z "$RPM_PACKAGE_RELEASE" ]; then
        case "$PACKAGE_VERSION" in
            *[!0-9]*|'') RPM_PACKAGE_RELEASE=$(date -u +%Y%m%d%H%M%S) ;;
            *) RPM_PACKAGE_RELEASE=$PACKAGE_VERSION ;;
        esac
    fi
    case "$RPM_PACKAGE_RELEASE" in
        *[!0-9]*|''|0)
            printf 'Invalid RPM package release: %s (expected a positive integer)\n' \
                "$RPM_PACKAGE_RELEASE" >&2
            exit 1
            ;;
    esac
fi

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

mkdir -p "$OUTPUT_DIR"
if [ "$PACKAGE_FORMAT" = deb ]; then
    make -C "$SOURCE_DIR" -j"$(nproc)" O="$BUILD_DIR" \
        KDEB_PKGVERSION="$PACKAGE_VERSION" bindeb-pkg

    find "$WORK_ROOT" -maxdepth 1 -type f \
        -name "*_${PACKAGE_VERSION}_amd64.deb" -exec cp {} "$OUTPUT_DIR/" \;

    if ! find "$OUTPUT_DIR" -maxdepth 1 -type f \
        -name "linux-image-*_${PACKAGE_VERSION}_amd64.deb" | grep -q .; then
        printf 'No linux-image package was produced for package version %s.\n' \
            "$PACKAGE_VERSION" >&2
        exit 1
    fi

    (cd "$OUTPUT_DIR" && \
        sha256sum ./*_"$PACKAGE_VERSION"_amd64.deb > "$CHECKSUM_FILE")
else
    previous_release=$(expr "$RPM_PACKAGE_RELEASE" - 1)
    printf '%s\n' "$previous_release" > "$BUILD_DIR/.version"
    make -C "$SOURCE_DIR" -j"$(nproc)" O="$BUILD_DIR" \
        RPMOPTS="${RPMOPTS:---without debuginfo}" binrpm-pkg

    find "$BUILD_DIR/rpmbuild/RPMS" -type f -name '*.rpm' \
        -exec cp {} "$OUTPUT_DIR/" \;

    if ! find "$OUTPUT_DIR" -maxdepth 1 -type f \
        -name "kernel-[0-9]*-${RPM_PACKAGE_RELEASE}.*.rpm" | grep -q .; then
        printf 'No kernel RPM was produced for package release %s.\n' \
            "$RPM_PACKAGE_RELEASE" >&2
        exit 1
    fi

    (cd "$OUTPUT_DIR" && \
        sha256sum ./*-"$RPM_PACKAGE_RELEASE".*.rpm > "$CHECKSUM_FILE")
fi

printf 'Build complete (%s). Packages are in %s\n' \
    "$PACKAGE_FORMAT" "$OUTPUT_DIR"
