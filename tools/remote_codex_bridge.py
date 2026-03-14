#!/usr/bin/env python3
import argparse
import http.server
import select
import signal
import socket
import socketserver
import sys
import threading
import urllib.parse
import traceback

import paramiko


class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class ProxyHandler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "LocalProxy"
    sys_version = ""
    timeout = 60

    def log_message(self, fmt, *args):
        sys.stderr.write("[proxy] " + fmt % args + "\n")

    def do_CONNECT(self):
        host, port = self.path.split(":", 1)
        self._tunnel(host, int(port))

    def do_GET(self):
        self._forward_http()

    def do_POST(self):
        self._forward_http()

    def do_PUT(self):
        self._forward_http()

    def do_DELETE(self):
        self._forward_http()

    def do_HEAD(self):
        self._forward_http()

    def do_OPTIONS(self):
        self._forward_http()

    def _tunnel(self, host: str, port: int):
        upstream = socket.create_connection((host, port), timeout=self.timeout)
        self.send_response(200, "Connection Established")
        self.send_header("Proxy-Agent", "LocalProxy")
        self.send_header("Connection", "keep-alive")
        self.end_headers()
        self.wfile.flush()

        sockets = [self.connection, upstream]
        try:
            while True:
                readable, _, _ = select.select(sockets, [], [], self.timeout)
                if not readable:
                    break
                for sock in readable:
                    data = sock.recv(65536)
                    if not data:
                        return
                    target = upstream if sock is self.connection else self.connection
                    target.sendall(data)
        finally:
            upstream.close()

    def _forward_http(self):
        parsed = urllib.parse.urlsplit(self.path)
        if not parsed.scheme or not parsed.netloc:
            self.send_error(400, "Absolute URL required")
            return

        host = parsed.hostname
        port = parsed.port or (443 if parsed.scheme == "https" else 80)
        path = urllib.parse.urlunsplit(("", "", parsed.path or "/", parsed.query, parsed.fragment))

        upstream = socket.create_connection((host, port), timeout=self.timeout)
        try:
            body = None
            length = int(self.headers.get("Content-Length", "0"))
            if length:
                body = self.rfile.read(length)

            request = f"{self.command} {path} HTTP/1.1\r\n"
            upstream.sendall(request.encode("utf-8"))

            for key, value in self.headers.items():
                if key.lower() == "proxy-connection":
                    continue
                upstream.sendall(f"{key}: {value}\r\n".encode("utf-8"))
            upstream.sendall(b"\r\n")
            if body:
                upstream.sendall(body)

            while True:
                data = upstream.recv(65536)
                if not data:
                    break
                self.wfile.write(data)
        finally:
            upstream.close()


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
                data = sock.recv(65536)
                if not data:
                    break
                channel.sendall(data)
            if channel in r:
                data = channel.recv(65536)
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
    parser.add_argument("--local-proxy-port", type=int, default=28080)
    args = parser.parse_args()

    server = ThreadingHTTPServer(("127.0.0.1", args.local_proxy_port), ProxyHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    print(f"[proxy] listening on 127.0.0.1:{args.local_proxy_port}", flush=True)

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
        server.shutdown()
        server.server_close()
        client.close()
        return 1

    transport.set_keepalive(30)
    transport.request_port_forward("127.0.0.1", int(args.remote_port))
    print(
        f"[tunnel] starting reverse HTTP proxy: remote 127.0.0.1:{args.remote_port} -> local 127.0.0.1:{args.local_proxy_port}",
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
        server.shutdown()
        server.server_close()
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
                args=(channel, "127.0.0.1", args.local_proxy_port),
                daemon=True,
            )
            thread.start()
    except Exception:
        traceback.print_exc()
    except KeyboardInterrupt:
        print("[tunnel] stopping", flush=True)
    finally:
        try:
            transport.cancel_port_forward("127.0.0.1", int(args.remote_port))
        except Exception:
            pass
        client.close()
        server.shutdown()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
