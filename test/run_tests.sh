#!/usr/bin/env bash
# Test funkcyjny gpu-idle-shutdown.sh (bezpięczny: DRY_RUN + mock nvidia-smi)
set -u
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$DIR")"
BIN="$DIR/fakebin"
STATE="$DIR/statefile"
OUT="/tmp/gidis_out.$$"

rm -rf "$BIN" "$STATE"; mkdir -p "$BIN"
install -m 0755 "$DIR/fake_nvidia_smi.sh" "$BIN/nvidia-smi"

# stałe środowisko testowe (eksportowane => widoczne dla subprocessów)
export PATH="$BIN:$PATH" FAKE_MODE=idle STATE_FILE="$STATE" DRY_RUN=1 IDLE_LIMIT=5

run() { # run <FAKE_MODE>
  FAKE_MODE="$1"
  bash "$REPO/gpu-idle-shutdown.sh" > "$OUT" 2>&1
  local rc=$?
  tail -n1 "$OUT"
  echo "  [rc=$rc state=$(cat "$STATE" 2>/dev/null || echo null)]"
}

echo "== A. idle x3 przy IDLE_LIMIT=5 (oczekiwane 1/5, 2/5, 3/5) =="
run idle
run idle
run idle

echo "== B. busy-util (util 55% > progu) => aktywna, licznik->0 =="
run busy-util

echo "== C. busy-app (procesy na GPU przy util 0) => aktywna, licznik->0 =="
run busy-app

echo "== D. 5 x idle => 5/5 i komunikat DRY RUN (BEZ poweroff) =="
rm -f "$STATE"
run idle; run idle; run idle; run idle; run idle
if grep -q 'DRY RUN' "$OUT"; then
  echo "  => OK: DRY RUN wystąpił przy 5/5, maszyna nie została wyłączona"
else
  echo "  => FAIL: brak komunikatu DRY RUN"
fi

echo "== E. broken driver (błąd/puste wyjście nvidia-smi) => UNKNOWN, licznik->0 =="
run broken

echo "== F. brak nvidia-smi w PATH => BRAK, licznik->0 =="
NVIDIA_SMI=nvidia-smi-czego-nie-ma bash "$REPO/gpu-idle-shutdown.sh" > "$OUT" 2>&1
tail -n1 "$OUT"; echo "  [state=$(cat "$STATE" 2>/dev/null || echo null)]"

echo "== G. uszkodzony licznik w pliku stanu => reset i odnowienie od 1/5 =="
printf 'abc\n' > "$STATE"
run idle

echo "== H. multi-GPU: jedna zajęta karta => całość aktywna, licznik->0 =="
run busy-util

echo; echo "Koniec testów."
