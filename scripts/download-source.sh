#!/bin/sh
set -eu

REPO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SOURCE_DIR=${SOURCE_DIR:-$REPO_DIR/source}
SOURCE_NAME=linux-source-7.0.0_7.0.0-29.29_all.deb
SOURCE_URL=${SOURCE_URL:-https://archive.ubuntu.com/ubuntu/pool/main/l/linux/$SOURCE_NAME}
SOURCE_SHA256=71d8d5ddcd210fa7b00583645a6b5e1141f8cb5cfd24763e3bb592e5846bfd7a
SOURCE_DEB=$SOURCE_DIR/$SOURCE_NAME

mkdir -p "$SOURCE_DIR"

if [ -f "$SOURCE_DEB" ]; then
    if printf '%s  %s\n' "$SOURCE_SHA256" "$SOURCE_DEB" | \
        sha256sum -c - >/dev/null 2>&1; then
        printf 'Using verified source package: %s\n' "$SOURCE_DEB"
        exit 0
    fi

    printf 'Removing source package with an invalid checksum: %s\n' "$SOURCE_DEB" >&2
    rm -f "$SOURCE_DEB"
fi

printf 'Downloading %s\n' "$SOURCE_URL"
curl --fail --location --retry 3 --retry-all-errors \
    --output "$SOURCE_DEB.part" "$SOURCE_URL"
mv "$SOURCE_DEB.part" "$SOURCE_DEB"
printf '%s  %s\n' "$SOURCE_SHA256" "$SOURCE_DEB" | sha256sum -c -
