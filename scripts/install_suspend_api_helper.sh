#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "This installer needs sudo because it writes /usr/local/sbin and /etc/sudoers.d." >&2
  exec sudo "$0" "$@"
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
helper_src="$repo_dir/pc/helpers/pc_suspend_with_wol"
helper_dst="/usr/local/sbin/pc_suspend_with_wol"
sudoers_dst="/etc/sudoers.d/phone-wol-power-suspend"
target_user="${PHONE_WOL_POWER_USER:-${SUDO_USER:-}}"

if [ -z "$target_user" ] || [ "$target_user" = "root" ]; then
  echo "Set PHONE_WOL_POWER_USER to the user that runs the PC API." >&2
  echo "Example: sudo PHONE_WOL_POWER_USER=alice $0" >&2
  exit 2
fi

install -o root -g root -m 0755 "$helper_src" "$helper_dst"

tmp="$(mktemp)"
cat > "$tmp" <<'EOF'
# Suspend wrapper used by the remote-control API.
# This reasserts wired WOL immediately before systemd suspend.
EOF
printf '%s ALL=(root) NOPASSWD: /usr/local/sbin/pc_suspend_with_wol\n' "$target_user" >> "$tmp"

chmod 0440 "$tmp"
if command -v visudo >/dev/null 2>&1; then
  visudo -cf "$tmp"
fi
install -o root -g root -m 0440 "$tmp" "$sudoers_dst"
rm -f "$tmp"

echo "Installed $helper_dst"
echo "Installed $sudoers_dst"
echo "Optional live test, only when you are ready for the PC to suspend:"
echo "  sudo -n /usr/local/sbin/pc_suspend_with_wol"
