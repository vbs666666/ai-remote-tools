#!/usr/bin/env bash
set -euo pipefail

PID_DIR="${PID_DIR:-$HOME/.cache/ai-remote-tools}"
pid_file="${PID_DIR}/ccswitch_4141_tunnel.pid"
if [ -f "$pid_file" ]; then
  pid="$(cat "$pid_file")"
  kill "$pid" 2>/dev/null || true
  rm -f "$pid_file"
fi
for proc in /proc/[0-9]*; do
  [ -r "$proc/cmdline" ] || continue
  cmd="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
  case "$cmd" in
    *"ssh -N"*127.0.0.1:43141:127.0.0.1:4141*)
      kill "${proc##*/}" 2>/dev/null || true
      ;;
  esac
done
echo "stopped"
