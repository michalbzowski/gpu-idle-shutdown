#!/usr/bin/env bash
#
# gpu-idle-shutdown.sh
#
# Uruchamiany co minutę przez systemd timer (jako root).
# Sprawdza, czy karta NVIDIA wykonuje obliczenia:
#   1) brak procesów obliczeniowych przypiętych do GPU (--query-compute-apps)
#   2) utilization.gpu poniżej progu (GPU_UTIL_MAX)
# Jeśli OBA warunki są spełnione — "idle". Po IDLE_LIMIT kolejnych idle
# wyłącza system (poweroff). Skrypt działa jako root, więc hasło sudo
# nie jest potrzebne. Zero obsługi po instalacji, startuje automatycznie
# po restarcie (systemd timer enabled).
#
set -euo pipefail

# ================== KONFIGURACJA (można nadpisać zmiennej środowiskowej) ==================
IDLE_LIMIT="${IDLE_LIMIT:-30}"         # ile KOLEJNYCH minut idle => poweroff
GPU_UTIL_MAX="${GPU_UTIL_MAX:-1}"      # utilization.gpu <= próg [%] uznajemy za brak obliczeń
NVIDIA_SMI="${NVIDIA_SMI:-nvidia-smi}" # ścieżka do nvidia-smi
STATE_FILE="${STATE_FILE:-/var/lib/gpu-idle-shutdown/state}"  # licznik idle checków
DRY_RUN="${DRY_RUN:-0}"                # 1 = tylko loguje zamiast wyłączać (bezpieczny test)

ts() { date '+%F %T'; }

# ================== 1. Czy w ogóle widzimy kartę? ==========================================
if ! command -v "$NVIDIA_SMI" >/dev/null 2>&1; then
  echo "[$(ts)] BRAK nvidia-smi — brak karty/drivera, pomijam bezpiecznie (licznik->0)"
  printf '0\n' > "${STATE_FILE}"
  exit 0
fi

# ================== 2. Odczyt stanu GPU ====================================================
# utilization per karta (csv bez nagłówka, np. "3\n42")
util_csv="$( "$NVIDIA_SMI" --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true )"
# procesy obliczeniowe na GPU (PID-y); puste = żaden proces nie używa komputera karta
apps_csv="$( "$NVIDIA_SMI" --query-compute-apps=pid --format=csv,noheader 2>/dev/null || true )"

busy=0
gpu_seen=0
while IFS= read -r u; do
  case "$u" in ''|*[!0-9]*) continue ;; esac
  gpu_seen=$((gpu_seen + 1))
  if [ "$u" -gt "$GPU_UTIL_MAX" ]; then
    busy=1   # karta liczy powyżej progu => aktywna
  fi
done <<< "${util_csv:-}"

# jakikolwiek proces obliczeniowy na GPU === aktywność (nawet przy 0% utilization w tej sekundzie)
if [ -n "${apps_csv//[[:space:]]/}" ]; then
  busy=1
fi

# ================== 3. Licznik "idle z rzędu" ==============================================
mkdir -p "$(dirname "$STATE_FILE")"
counter="$(cat "$STATE_FILE" 2>/dev/null || printf '0')"
case "$counter" in ''|*[!0-9]*) counter=0 ;; esac

if [ "$gpu_seen" -eq 0 ]; then
  # nie udało się odczytać utilization (błąd drivera itp.) — nie wyłączamy, licznik->0
  echo "[$(ts)] UNKNOWN: utilization nieczytelny (${util_csv:-puste}) — licznik->0"
  counter=0
elif [ "$busy" -eq 1 ]; then
  echo "[$(ts)] GPU AKTYWNA (util/apps) — licznik->0"
  counter=0
else
  counter=$((counter + 1))
  echo "[$(ts)] GPU IDLE — licznik $counter/$IDLE_LIMIT"
fi

printf '%s\n' "$counter" > "${STATE_FILE}"

# ================== 4. Shutdown po osiągnięciu progu =======================================
if [ "$gpu_seen" -gt 0 ] && [ "$busy" -eq 0 ] && [ "$counter" -ge "$IDLE_LIMIT" ]; then
  if [ "$DRY_RUN" = "1" ]; then
    echo "[$(ts)] DRY RUN: osiągnięto limit $IDLE_LIMIT kolejnych minut idle — NIE wyłączam maszyny"
  else
    echo "[$(ts)] $IDLE_LIMIT kolejnych minut bez obliczeń na GPU — poweroff za 5 s"
    sleep 5
    exec systemctl poweroff
  fi
fi
