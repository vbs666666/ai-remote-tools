#!/usr/bin/env python3
import argparse
import os
import posixpath
import stat
import sys

import paramiko


def mkdir_p(sftp: paramiko.SFTPClient, remote_dir: str) -> None:
    parts = []
    current = remote_dir
    while current not in ("", "/"):
        parts.append(current)
        current = posixpath.dirname(current)
    for path in reversed(parts):
        try:
            sftp.stat(path)
        except OSError:
            sftp.mkdir(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="connect.bjb1.seetacloud.com")
    parser.add_argument("--port", default="15570")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password", required=True)
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    if len(args.paths) < 2:
        parser.error("expected source and destination")

    source = args.paths[0]
    destination = args.paths[-1]
    prefix = f"{args.user}@{args.host}:"
    if not destination.startswith(prefix):
        parser.error("destination must be remote")
    remote_path = destination[len(prefix):]

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
    try:
        sftp = client.open_sftp()
        try:
            mkdir_p(sftp, posixpath.dirname(remote_path))
            sftp.put(source, remote_path)
            local_mode = os.stat(source).st_mode
            sftp.chmod(remote_path, stat.S_IMODE(local_mode))
        finally:
            sftp.close()
        return 0
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
