#!/usr/bin/env bash
# probe: czy "env VAR=val" jako "$@" działa w subshellu?
run() {
  local m="$1"
  shift
  echo "[test 1] with extra arg:"
  ( A=1 B=$m "$@" bash -c 'echo "  inside sees: B=$B, K=${K:-unset}"' ) || echo "  rc=$?"
  echo "[test 2] bare:"
  ( A=1 B=$m bash -c 'echo "  inside sees: B=$B"' ) || echo "  rc=$?"
}
run idle IDLE_LIMIT=5
