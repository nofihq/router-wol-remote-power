#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" != "--confirm" ]; then
  cat >&2 <<'EOF'
Refusing to suspend without confirmation.

This uses systemd suspend so driver-managed suspend hooks can run. That matters
on systems where GPU drivers, especially NVIDIA, need their systemd suspend and
resume services.

Run:

  ./scripts/suspend_via_systemd.sh --confirm
EOF
  exit 2
fi

config_file="${PHONE_WOL_POWER_ENV:-/etc/phone-wol-power/pc.env}"
eth_if="${WOL_ETH_IF:-${WIRED_IFACE:-}}"

if [ -z "$eth_if" ] && [ -r "$config_file" ]; then
  eth_if="$(sed -n 's/^WIRED_IFACE=//p' "$config_file" | tail -n 1)"
fi

if [ -z "$eth_if" ]; then
  echo "Set WOL_ETH_IF, WIRED_IFACE, or WIRED_IFACE in $config_file." >&2
  exit 2
fi

case "$eth_if" in
  *[!A-Za-z0-9_.:-]*)
    echo "Invalid Ethernet interface: $eth_if" >&2
    exit 2
    ;;
esac
running_as_root=0

if [ "$(id -u)" -ne 0 ]; then
  if [ -t 0 ]; then
    echo "Re-running with sudo so WOL can be reasserted before suspend." >&2
    exec sudo --preserve-env=PATH,WOL_ETH_IF,WIRED_IFACE,PHONE_WOL_POWER_ENV "$0" "$@"
  fi
  echo "No terminal is available for sudo; continuing with systemd suspend without reasserting WOL." >&2
else
  running_as_root=1
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="${WOL_SUSPEND_LOG_DIR:-$repo_dir/logs/suspend}"
if ! mkdir -p "$log_dir" 2>/dev/null; then
  log_dir="${XDG_RUNTIME_DIR:-/tmp}/wol-suspend"
  mkdir -p "$log_dir"
fi
log_file="$log_dir/suspend-$(date +%Y%m%d-%H%M%S).log"

{
  echo "WOL systemd suspend"
  date --iso-8601=seconds
  uname -a
  echo "pm_test: $(cat /sys/power/pm_test)"
  echo "mem_sleep: $(cat /sys/power/mem_sleep)"
  echo "--- default routes ---"
  ip route show default || true
  echo "--- NVIDIA suspend services ---"
  systemctl is-enabled nvidia-suspend.service nvidia-resume.service 2>&1 || true
  echo "--- NVIDIA params ---"
  sed -n '/PreserveVideoMemoryAllocations/p;/TemporaryFilePath/p' /proc/driver/nvidia/params 2>/dev/null || true
  if [ "$running_as_root" = "1" ]; then
    echo "--- Ethernet WOL before reassert ---"
    ethtool "$eth_if" 2>/dev/null | grep -E 'Supports Wake-on|Wake-on' || true
  else
    echo "Running without root; skipping Ethernet WOL reassert."
  fi
} | tee "$log_file"

if [ "$running_as_root" = "1" ] && { [ -x /usr/sbin/ethtool ] || command -v ethtool >/dev/null 2>&1; }; then
  ethtool -s "$eth_if" wol g 2>&1 | tee -a "$log_file" || true
fi

{
  if [ "$running_as_root" = "1" ]; then
    echo "--- Ethernet WOL after reassert ---"
    ethtool "$eth_if" 2>/dev/null | grep -E 'Supports Wake-on|Wake-on' || true
  fi
  echo "Calling systemctl suspend at $(date --iso-8601=seconds)"
} | tee -a "$log_file"

systemctl suspend
