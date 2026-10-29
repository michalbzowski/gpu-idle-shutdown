#!/usr/bin/env bash
# fake nvidia-smi — zachowanie sterowane FAKE_MODE (idle | busy-util | busy-app | broken)
# Obsługuje oba style wywołań: --query-gpu X / --query-gpu=X
mode="${FAKE_MODE:-idle}"
print_util() {
  case "$mode" in
    idle)       printf '0\n1\n' ;;
    busy-util)  printf '3\n55\n' ;;
    busy-app)   printf '0\n0\n' ;;
    broken)     echo "ERROR: No devices were found." >&2; exit 9 ;;
  esac
}
print_apps() {
  case "$mode" in
    idle|busy-util|broken) printf '' ;;
    busy-app)              printf '12345\n67890\n' ;;
  esac
}
case "$1" in
  --query-gpu|--query-gpu=*) print_util ;;
  --query-compute-apps|--query-compute-apps=*) print_apps ;;
  *) exit 0 ;;
esac
