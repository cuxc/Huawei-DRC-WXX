#!/bin/sh
set -eu

printf '%s\n' '=== DMI ==='
printf 'sys_vendor: '; cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true
printf 'product_name: '; cat /sys/class/dmi/id/product_name 2>/dev/null || true
printf '%s\n' '=== Kernel ==='
uname -r
printf '%s\n' '=== Command line ==='
cat /proc/cmdline
printf '%s\n' '=== Sleep state ==='
printf 'mem_sleep: '; cat /sys/power/mem_sleep 2>/dev/null || true
printf 'drm.debug: '; cat /sys/module/drm/parameters/debug 2>/dev/null || true
printf '%s\n' '=== Lid switch handling ==='
systemd-inhibit --list 2>/dev/null | grep -i 'handle-lid-switch' || \
    printf 'no handle-lid-switch inhibitor\n'
printf '%s\n' '=== Relevant kernel log (this boot) ==='
journalctl -k -b --no-pager 2>/dev/null | \
    grep -iE 'Applying Huawei DRC-WXX|Forcing full modeset|GPIO index|DCS NOP|LPTX|not disabled|not idle|ULPS|DSB|pipe state|mismatch|PM: suspend|Restoring old state|i915.*ERROR' || true
printf '%s\n' '=== Relevant kernel log (previous boot) ==='
if journalctl -k -b -1 --no-pager >/dev/null 2>&1; then
    journalctl -k -b -1 --no-pager 2>/dev/null | \
        grep -iE 'Applying Huawei DRC-WXX|Forcing full modeset|GPIO index|DCS NOP|LPTX|not disabled|not idle|ULPS|DSB|pipe state|mismatch|PM: suspend|Restoring old state|i915.*ERROR' || true
else
    printf 'no persistent journal; run "sudo ./scripts/sleep-debug.sh install"\n'
fi
printf '%s\n' '=== Captured resume dump ==='
if [ -f /var/log/drc-wxx-resume.log ]; then
    grep -iE 'Applying Huawei DRC-WXX|Forcing full modeset|GPIO index|DCS NOP|LPTX|not disabled|not idle|ULPS|DSB|pipe state|mismatch|PM: suspend|Restoring old state|i915.*ERROR' \
        /var/log/drc-wxx-resume.log || true
else
    printf 'not captured; run "sudo ./scripts/sleep-debug.sh install"\n'
fi
