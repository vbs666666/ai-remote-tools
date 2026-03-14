#!/usr/bin/env bash
set -euo pipefail

PID_DIR="${PID_DIR:-$HOME/.cache/ai-remote-tools}"

for name in reverse_tunnel local_proxy; do
  pid_file="${PID_DIR}/${name}.pid"
  if [ -f "$pid_file" ]; then
    pid="$(cat "$pid_file")"
    kill "$pid" 2>/dev/null || true
    rm -f "$pid_file"
  fi
done
for proc in /proc/[0-9]*; do
  [ -r "$proc/cmdline" ] || continue
  cmd="$(tr '\0' ' ' < "$proc/cmdline" 2>/dev/null || true)"
  case "$cmd" in
    *"ssh -N"*127.0.0.1:38080*)
      kill "${proc##*/}" 2>/dev/null || true
      ;;
    *local_http_connect_proxy.py*"--port 28080"*)
      kill "${proc##*/}" 2>/dev/null || true
      ;;
  esac
done

echo "stopped"
