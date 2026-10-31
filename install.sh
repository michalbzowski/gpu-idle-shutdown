#!/usr/bin/env bash
#
# install.sh — jednorazowa instalacja / odinstalowanie na Ubuntu (20.04+/22.04/24.04).
#   sudo ./install.sh           # instaluje i startuje timer
#   sudo ./install.sh uninstall # usuwa całość
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Uruchom jako root: sudo $0 $*"
  exit 1
fi

cmd="${1:-install}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$cmd" in
  install)
    install -m 0755 "$SRC_DIR/gpu-idle-shutdown.sh" /usr/local/bin/gpu-idle-shutdown.sh
    install -m 0644 "$SRC_DIR/gpu-idle-check.service" /etc/systemd/system/
    install -m 0644 "$SRC_DIR/gpu-idle-check.timer"   /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable --now gpu-idle-check.timer
    echo
    systemctl list-timers --all | grep -i gpu-idle || true
    echo
    echo "OK. Pierwsze sprawdzenie ~60 s po starcie systemu."
    echo "Test BEZ wyłączania maszyny:"
    echo "  sudo DRY_RUN=1 /usr/local/bin/gpu-idle-shutdown.sh"
    ;;
  uninstall)
    systemctl disable --now gpu-idle-check.timer || true
    rm -f /etc/systemd/system/gpu-idle-check.service \
          /etc/systemd/system/gpu-idle-check.timer \
          /usr/local/bin/gpu-idle-shutdown.sh
    rm -rf /var/lib/gpu-idle-shutdown
    systemctl daemon-reload
    echo "OK — odinstalowano."
    ;;
  *)
    echo "Użycie: $0 [install|uninstall]"
    exit 1
    ;;
esac
