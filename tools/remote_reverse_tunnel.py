#!/usr/bin/env python3
import argparse
import select
import signal
import socket
import sys
import threading
import time

import paramiko


def bridge_channel(channel: paramiko.Channel, local_host: str, local_port: int) -> None:
    sock = socket.socket()
    try:
        sock.connect((local_host, local_port))
    except OSError as exc:
        print(f"[tunnel] local connect failed: {local_host}:{local_port}: {exc}", file=sys.stderr, flush=True)
        channel.close()
        sock.close()
        return

    try:
        while True:
            r, _, _ = select.select([sock, channel], [], [])
            if sock in r:
                data = sock.recv(4096)
                if not data:
                    break
                channel.sendall(data)
            if channel in r:
                data = channel.recv(4096)
                if not data:
                    break
                sock.sendall(data)
    finally:
        channel.close()
        sock.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--remote-port", required=True)
    parser.add_argument("--local-port")
    parser.add_argument("--remote-dynamic", action="store_true")
    args = parser.parse_args()

    if args.remote_dynamic:
        print("[tunnel] remote dynamic SOCKS is not supported by the Windows-native path yet", file=sys.stderr)
        return 2
    if not args.local_port:
        parser.error("--local-port is required unless --remote-dynamic is set")

    local_port = int(args.local_port)
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.settimeout(2)
        try:
            sock.connect(("127.0.0.1", local_port))
        except OSError as exc:
            print(f"[tunnel] local preflight failed: 127.0.0.1:{local_port} is not reachable: {exc}", file=sys.stderr)
            return 1

    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect(
        hostname=args.host,
        port=int(args.port),
        username=args.user,
        password=args.password,
        look_for_keys=False,
        allow_agent=False,
        timeout=20,
    )
    transport = client.get_transport()
    if transport is None:
        print("[tunnel] ssh transport unavailable", file=sys.stderr)
        client.close()
        return 1

    transport.request_port_forward("127.0.0.1", int(args.remote_port))
    print(
        f"[tunnel] starting reverse tunnel: remote 127.0.0.1:{args.remote_port} -> local 127.0.0.1:{local_port}",
        flush=True,
    )
    print("[tunnel] ssh tunnel is running", flush=True)

    stop_event = threading.Event()

    def cleanup(*_args):
        print("[tunnel] stopping", flush=True)
        stop_event.set()
        try:
            transport.cancel_port_forward("127.0.0.1", int(args.remote_port))
        except Exception:
            pass
        client.close()
        sys.exit(0)

    signal.signal(signal.SIGINT, cleanup)
    signal.signal(signal.SIGTERM, cleanup)

    try:
        while not stop_event.is_set():
            channel = transport.accept(timeout=1)
            if channel is None:
                if not transport.is_active():
                    break
                continue
            thread = threading.Thread(
                target=bridge_channel,
                args=(channel, "127.0.0.1", local_port),
                daemon=True,
            )
            thread.start()
    finally:
        client.close()

    print("[tunnel] ssh exited", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
