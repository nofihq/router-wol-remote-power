#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  ./scripts/configure_idle_suspend.sh --enable-2h
  ./scripts/configure_idle_suspend.sh --disable
  ./scripts/configure_idle_suspend.sh --status

This configures GNOME's AC idle suspend setting for the current desktop user.
It uses the normal systemd suspend path, so NVIDIA's suspend/resume services run.
EOF
}

show_status() {
  echo "sleep-inactive-ac-type=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type)"
  echo "sleep-inactive-ac-timeout=$(gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout)"
  echo "idle-delay=$(gsettings get org.gnome.desktop.session idle-delay)"
}

case "${1:-}" in
  --enable-2h)
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 7200
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type suspend
    show_status
    ;;
  --disable)
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
    show_status
    ;;
  --status)
    show_status
    ;;
  *)
    usage
    exit 2
    ;;
esac
