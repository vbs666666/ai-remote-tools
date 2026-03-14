#!/usr/bin/env python3
import argparse
import http.server
import select
import socket
import socketserver
import sys
import urllib.parse


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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=28080)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), ProxyHandler)
    print(f"[proxy] listening on {args.host}:{args.port}", flush=True)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
