# craftos-mcp

An MCP server that drives an **embedded [CraftOS-PC](https://github.com/MCJack123/craftos2)**
emulator to run simulated, multi-computer ComputerCraft tests — rednet and GPS —
as MCP tools. The whole emulator is linked into a Rust ([`rmcp`](https://github.com/modelcontextprotocol/rust-sdk))
server; computers boot headless and talk to each other over an in-process
wireless-modem network.

The canonical test is **GPS**: 4 wireless GPS hosts at known coordinates plus a
client, where `gps.locate()` must trilaterate the client's true position.

## Endpoints (served concurrently on one port)

| Path | Transport |
|------|-----------|
| `POST/GET /mcp` | Streamable HTTP (MCP 2025-03-26+) |
| `GET /sse` + `POST /message` | Legacy HTTP+SSE (MCP 2024-11-05) |
| `GET /health` | Liveness (for Railway) |

## Tools

- **`gps_selftest`** — boot 4 GPS hosts + a client and verify `gps.locate()`
  returns the client's true position `(3,4,5)`. Returns `{pass, expected, detail}`.

## Session isolation

Each tool call runs on its **own modem network (`netID`) and computer-id block**,
so concurrent sessions never cross-talk — two clients can run `gps_selftest`
simultaneously and get independent, correct results. (This is in-process
isolation; it is not yet OS/clock-level deterministic isolation.)

## Deploy on Railway

This repo is a Dockerfile deploy. Point Railway at it; it builds the emulator
(SDL2 + Poco + OpenSSL) and the Rust server, then runs both endpoints on `$PORT`.

The Dockerfile clones the emulator + server source from the
[`r33drichards/craftos2`](https://github.com/r33drichards/craftos2) fork
(`turtle-sim` branch) and the ROM from `MCJack123/craftos2-rom`. Override with
build args `CRAFTOS_REPO` / `CRAFTOS_REF`.

## Connect a client

- Streamable HTTP: `https://<app>.up.railway.app/mcp`
- Legacy SSE: `https://<app>.up.railway.app/sse`

## Local

```bash
docker build -t craftos-mcp .
docker run -p 8080:8080 craftos-mcp
curl localhost:8080/health        # -> ok
```
