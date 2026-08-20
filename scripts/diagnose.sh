#!/bin/sh
set -eu

printf '%s\n' '=== DMI ==='
printf 'sys_vendor: '; cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true
printf 'product_name: '; cat /sys/class/dmi/id/product_name 2>/dev/null || true
printf '%s\n' '=== Kernel ==='
uname -r
printf '%s\n' '=== Command line ==='
cat /proc/cmdline
printf '%s\n' '=== Relevant kernel log ==='
journalctl -k -b --no-pager 2>/dev/null | \
    grep -iE 'Applying Huawei DRC-WXX|Skipping initial display|DSB|pipe state|mismatch|i915.*ERROR' || true
