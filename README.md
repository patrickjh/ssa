# Simple Shell Agent (ssa)

`ssa` is a simple AI agent in one POSIX `sh` file. Inspired by
[mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent): give the
model **only shell**, run each step in a **fresh process**, keep a
**simple loop**. Feels like a unix util.

## Requirements

- POSIX `sh`, plus `curl` and `jq` on `PATH`
- Linux and macOS work as usual; on Windows use WSL (ssa targets POSIX
  systems only)
- A chat-completions URL in `OPENAI_URL` (or `--openai-url`). Curl
  POSTs the OpenAI-style body there; the path need not end in
  `/chat/completions`.

Any OpenAI-compatible endpoint works (OpenAI, local proxies, and similar
providers). Set `OPENAI_API_KEY` when the provider requires auth.

## Install

```sh
git clone https://github.com/patrickjh/ssa.git
cd ssa
chmod +x ssa
export PATH="$PWD:$PATH"
```

Or download the `ssa` file alone, `chmod +x`, and put its folder on
`PATH`.

## Try it

```sh
export OPENAI_API_KEY="sk-..."
export OPENAI_URL="https://api.openai.com/v1/chat/completions"
ssa -m gpt-4o-mini summarize this repo
```

Or with flags:

```sh
export OPENAI_API_KEY="sk-..."
ssa --openai-url "https://api.openai.com/v1/chat/completions" \
  -m gpt-4o-mini summarize this repo
```

Task on stdin:

```sh
echo "summarize this repo" | ssa \
  --openai-url "https://api.openai.com/v1/chat/completions" \
  -m gpt-4o-mini
```

Batch / no TTY: add `--no-ask`. Keep temp logs: `--keep-temp`. Extra
request fields (`think`, `max_tokens`, sampling): `--request-json`.

**Unix-shaped.** Handle `cd`, env, and redirects in the shell. Script
output streams live on **stdout**. Agent messages (ask UI, errors, final
status) go to **stderr**.

## Local models

Point `OPENAI_URL` at llama.cpp (or another server that honors
`think: false`). ssa does not default that; pass it in
`--request-json`. Local `max_tokens` defaults are often 256–2048 and
will truncate write requests.

```sh
export OPENAI_URL=http://127.0.0.1:8080/v1/chat/completions
ssa -m gemma-4-31b \
  --request-json '{"think":false,"max_tokens":8192,"temperature":1,"top_p":0.95}' \
  --keep-temp --max-model-prompts 30 \
  fix the failing test
```

Add `--no-ask` when there is no TTY.

## Safety

`ssa` runs shell scripts written by the model in your current directory.
Treat that like handing the model your terminal.

- **Ask-user approval is on by default** — each model script is shown on
  stderr; you approve from `/dev/tty` (`[Y]es` / `[N]o` / `[Q]uit`).
- Optional **sandbox command**: `--sandbox-command` /
  `SSA_SANDBOX_COMMAND` (default `sh`; use your own wrapper for
  containers, pledge, jails, or a wall-clock timeout).
  `COMMAND` is one executable (`command -v`), not `timeout 60 sh`.
  A hung script (`tail -f`) or a background child that keeps stdout
  open will block `tee` until that wrapper uses `timeout` /
  `timelimit` and a process group (`timeout --foreground`, or
  `setsid`) around `sh`, passing `"$@"` through so write/edit `-c`
  still works.

## Docs

- Full usage and defaults: `ssa -h`
- Design and coding style for contributors and coding agents:
  [AGENTS.md](AGENTS.md)

## Tests

```sh
sh tests/runTests.sh
```

That is the only supported entry point. Do not run `*.test.sh` files
alone.

## Layout

```
ssa/
├── AGENTS.md   # design + style for coding agents
├── LICENSE
├── README.md   # this file
├── ssa         # the agent (single file)
└── tests/      # live stories; sh tests/runTests.sh
```

## License

MIT — see [LICENSE](LICENSE).
