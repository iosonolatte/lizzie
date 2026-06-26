#!/usr/bin/env python3
"""Tiny mock KataGo for testing the lizzie-server proxy.

Accepts the same CLI flags as a real KataGo build (--config, --model)
and then reads GTP commands from stdin, responding with `=N ...` for
each one. `quit` causes a clean exit.
"""
import sys


def main() -> int:
    # Skip CLI flags: just consume --flag value pairs.
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a.startswith("--") and i + 1 < len(args) and not args[i + 1].startswith("--"):
            i += 2
        else:
            i += 1

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        parts = line.split(" ", 1)
        cmd_num = parts[0]
        cmd = parts[1] if len(parts) > 1 else ""
        if cmd == "quit":
            print(f"={cmd_num} ")
            sys.stdout.flush()
            return 0
        if cmd == "name":
            print(f"={cmd_num} MockKataGo")
        elif cmd == "version":
            print(f"={cmd_num} 1.0.0-mock")
        elif cmd.startswith("boardsize") or cmd.startswith("komi") or cmd.startswith("clear_board"):
            print(f"={cmd_num} ")
        elif cmd.startswith("play") or cmd == "undo":
            print(f"={cmd_num} ")
        elif cmd.startswith("kata-analyze") or cmd.startswith("lz-analyze"):
            # Emit a few info lines then a blank result on quit/stop.
            for i in range(3):
                print(
                    f"info move Q{i+5} visits 100 winrate 50.0 scoreMean 0.0 "
                    f"scoreStdev 1.0 pv Q{i+5}"
                )
            # Don't return; keep reading.
            continue
        else:
            print(f"={cmd_num} ")
        sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
