#!/bin/sh
# Capture kernel logs across suspend/resume when the panel does not come back.
set -eu

HOOK=/usr/lib/systemd/system-sleep/99-drc-wxx
JOURNALD_DROPIN=/etc/systemd/journald.conf.d/90-drc-wxx.conf
RESUME_LOG=/var/log/drc-wxx-resume.log
PRESLEEP_LOG=/var/log/drc-wxx-presleep.log

usage() {
    cat <<'EOF'
Usage: sleep-debug.sh <install|collect|uninstall>

  install     Enable persistent journald, a resume dmesg hook and KMS debug.
  collect     Gather captured logs into a tarball in the current directory.
  uninstall   Remove the hook and journald drop-in.
EOF
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        printf 'This command needs root. Re-run with sudo.\n' >&2
        exit 1
    fi
}

install_hook() {
    require_root

    mkdir -p /var/log/journal "$(dirname "$JOURNALD_DROPIN")"
    systemd-tmpfiles --create --prefix /var/log/journal >/dev/null 2>&1 || true
    cat > "$JOURNALD_DROPIN" <<'EOF'
# Added by Huawei-DRC-WXX/scripts/sleep-debug.sh
[Journal]
Storage=persistent
SyncIntervalSec=1s
EOF
    systemctl restart systemd-journald
    journalctl --flush >/dev/null 2>&1 || true

    mkdir -p "$(dirname "$HOOK")"
    cat > "$HOOK" <<'EOF'
#!/bin/sh
case "$1" in
pre)
    dmesg -T > /var/log/drc-wxx-presleep.log 2>&1 || true
    sync
    ;;
post)
    if command -v setsid >/dev/null 2>&1; then
        setsid sh -c 'sleep 8; dmesg -T > /var/log/drc-wxx-resume.log 2>&1; sync' &
    else
        sh -c 'sleep 8; dmesg -T > /var/log/drc-wxx-resume.log 2>&1; sync' &
    fi
    ;;
esac
exit 0
EOF
    chmod 0755 "$HOOK"

    if [ -w /sys/module/drm/parameters/debug ]; then
        printf '0x1e\n' > /sys/module/drm/parameters/debug
    fi
    printf 'Installed resume logging at %s\n' "$RESUME_LOG"
}

collect_logs() {
    stamp=$(date -u +%Y%m%d-%H%M%S)
    out="drc-wxx-logs-$stamp"
    mkdir -p "$out"

    for f in "$PRESLEEP_LOG" "$RESUME_LOG"; do
        [ -f "$f" ] && cp "$f" "$out/" || true
    done
    dmesg -T > "$out/dmesg-now.log" 2>&1 || true
    journalctl -k -b --no-pager > "$out/kernel-this-boot.log" 2>&1 || true
    journalctl -k -b -1 --no-pager > "$out/kernel-previous-boot.log" 2>&1 || true
    systemd-inhibit --list > "$out/inhibitors.txt" 2>&1 || true
    {
        printf 'uname: %s\n' "$(uname -r)"
        printf 'cmdline: %s\n' "$(cat /proc/cmdline)"
        printf 'sys_vendor: %s\n' "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
        printf 'product_name: %s\n' "$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
        printf 'mem_sleep: %s\n' "$(cat /sys/power/mem_sleep 2>/dev/null)"
    } > "$out/system.txt" 2>&1 || true

    tar czf "$out.tar.gz" "$out"
    rm -rf "$out"
    printf 'Wrote %s.tar.gz\n' "$out"
}

uninstall_hook() {
    require_root
    rm -f "$HOOK" "$JOURNALD_DROPIN"
    systemctl restart systemd-journald
    printf 'Removed the sleep hook and journald drop-in.\n'
}

case "${1:-}" in
    install) install_hook ;;
    collect) collect_logs ;;
    uninstall) uninstall_hook ;;
    *) usage; exit 1 ;;
esac
