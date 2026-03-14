#!/usr/bin/env python3
import argparse
import shlex
import sys

import paramiko


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="connect.bjb1.seetacloud.com")
    parser.add_argument("--port", default="15570")
    parser.add_argument("--user", default="root")
    parser.add_argument("--password", required=True)
    parser.add_argument("--stdin-script", action="store_true")
    parser.add_argument("remote_command", nargs=argparse.REMAINDER)
    args = parser.parse_args()

    if not args.stdin_script and not args.remote_command:
        parser.error("missing remote command")
    remote_command = list(args.remote_command)
    if remote_command and remote_command[0] == "--":
        remote_command = remote_command[1:]
    if not args.stdin_script and not remote_command:
        parser.error("missing remote command")

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
        if args.stdin_script:
            command = "bash -s"
            stdin_data = sys.stdin.read()
        else:
            command = shlex.join(remote_command)
            stdin_data = None

        stdin, stdout, stderr = client.exec_command(command)
        if stdin_data:
            stdin.write(stdin_data)
            stdin.channel.shutdown_write()
        out = stdout.read()
        err = stderr.read()
        if out:
            sys.stdout.buffer.write(out)
        if err:
            sys.stderr.buffer.write(err)
        return stdout.channel.recv_exit_status()
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())
