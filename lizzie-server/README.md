# lizzie-server

A tiny single-user TCP proxy that bridges the
[Lizzie Mobile Flutter app](../lizzie_mobile) to a local KataGo
subprocess. The server listens for GTP-over-TCP connections from the
mobile client, lazily spawns a KataGo subprocess on first use, and
bidirectionally forwards bytes between the client and KataGo's
stdin/stdout. A second client connection kicks the first.

```
   ┌──────────────┐  TCP :7878  ┌──────────────┐  stdio  ┌─────────┐
   │ Lizzie       │ ──────────► │ lizzie-server │ ──────► │ katago  │
   │ Mobile app   │ ◄────────── │ (this repo)   │ ◄────── │ process │
   └──────────────┘             └──────────────┘         └─────────┘
```

The mobile app needs no changes: it already has a `RemoteEngine` that
opens a raw TCP socket and speaks GTP. Point it at the host where
`lizzie-server` is running and it works.

## Why

Running KataGo directly is a hassle on a phone:

- Neural-net models are 50–100 MB.
- The binary has to be cross-compiled for `arm64-v8a` / `x86_64`.
- Battery, thermal throttling, and slow storage make on-device analysis
  painful.

A small server on the same Wi-Fi network (a laptop, a Raspberry Pi, a
home server, a cloud VM) hosts KataGo once and serves the phone over
TCP. The server is single-user, single-binary, and zero-config beyond
"point at the right port".

## Build

Requires Go 1.22+ (tested with 1.26.4).

```sh
cd lizzie-server
go build -o lizzie-server .
go test ./...      # unit tests for the helper functions
```

Cross-compile for common targets:

```sh
# Linux x86_64
GOOS=linux GOARCH=amd64 go build -o lizzie-server-linux-amd64 .
# Linux arm64 (Raspberry Pi, etc.)
GOOS=linux GOARCH=arm64 go build -o lizzie-server-linux-arm64 .
# macOS (universal)
GOOS=darwin GOARCH=amd64 go build -o lizzie-server-darwin-amd64 .
GOOS=darwin GOARCH=arm64 go build -o lizzie-server-darwin-arm64 .
# Windows
GOOS=windows GOARCH=amd64 go build -o lizzie-server.exe .
```

The resulting binary is self-contained (no Go runtime needed on the
target).

## Run

```sh
./lizzie-server \
    --addr :7878 \
    --katago /path/to/katago \
    --config /path/to/gtp.cfg \
    --model /path/to/kata1-b18c384nbt-s9996604416-d4316597426.bin.gz
```

### Flags

| Flag | Default | Description |
| --- | --- | --- |
| `--addr` | `:7878` | Listen address (`host:port` or `:port`). |
| `--katago` | `katago` | Path to the KataGo binary, or a name on `PATH`. |
| `--config` | `gtp.cfg` | Path to a KataGo GTP config file. **Required** (file is stat'd at startup). |
| `--model` | (empty) | Path to a neural-net model (`.bin.gz`). Empty = let the config file decide (it should contain `model = ...`). |
| `--verbose` | `false` | Log every byte forwarded. Extremely noisy; for debugging only. |
| `--max-idle` | `0` | Shut down the KataGo subprocess after this much idle time. `0` (default) keeps it alive for the lifetime of the server. |
| `--shutdown-timeout` | `5s` | Max time to wait for KataGo to exit after SIGINT (then it gets SIGKILLed). |

### Environment

- `OMP_NUM_THREADS` is set to `2` for the KataGo subprocess unless it's
  already set in the environment. Override by exporting it before
  running the server.

## Behavior

- **Lazy start**: KataGo is only spawned when the first client connects.
- **Single user**: a second client connection immediately kicks the
  first. This is intentional; running multiple KataGo processes per
  host is expensive (3+ GB of RAM each once the model is loaded) and
  the current Lizzie Mobile app is single-user.
- **Idle shutdown**: with `--max-idle`, the subprocess is killed after
  the configured idle time and re-spawned on the next connection.
- **Graceful shutdown**: `Ctrl-C` (SIGINT) or `kill <pid>` (SIGTERM)
  causes the server to send a `quit` GTP command, wait for KataGo to
  exit, and only SIGKILL if it doesn't. Any active client connection
  is closed.
- **No config mutation**: the server does not write to the
  KataGo config file. It just points KataGo at the user's existing
  config.

## Pairing with Lizzie Mobile

In the Lizzie Mobile app, open the engine settings sheet and set:

- **Engine type**: KataGo
- **Host**: the IP of the machine running `lizzie-server`
  (e.g. `192.168.1.42` on the home Wi-Fi, or a public IP if exposed
  through a tunnel)
- **Port**: the `--addr` port (default `7878`)

The app will `name` / `version` handshake on connect, the same way it
talks to a directly-running KataGo.

### Quick local smoke test

```sh
# In one terminal
./lizzie-server --katago ./katago --config ./gtp.cfg --model ./model.bin.gz

# In another
nc localhost 7878
> 1 name
< 1 KataGo
> 2 version
< 2 1.15.0
> 3 boardsize 19
< 3 =
> 4 quit
< 4 =
```

(The `> ` / `< ` prefixes are the local echoes from `nc`; the actual
GTP responses are on the right.)

### Smoke test without a real KataGo

For development or CI on a machine without KataGo installed, point
`--katago` at the bundled Python mock:

```sh
# In one terminal
./lizzie-server --katago python --config ./gtp.cfg mock_katago.py

# In another
nc localhost 7878
> 1 name
< 1 MockKataGo
> 2 version
< 2 1.0.0-mock
```

`mock_katago.py` is a 57-line script that accepts the same CLI flags
as a real KataGo and emits canned GTP responses. It's not in the
binary build path; it just makes smoke testing possible anywhere
Python is installed.

## License

Same as the parent Lizzie project.
