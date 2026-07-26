# Simple Shell Agent (ssa)

`ssa` is a simple AI agent in one POSIX `sh` file. Inspired by
[mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent): give the
model **only shell**, run each step in a **fresh process**, keep a
**simple loop**. Feels like a unix util.

**Needs:** `curl` and `jq` on `PATH`.

**Unix-shaped.** Invoke like `curl` or `make`: handle `cd`, env, and
redirects in the shell. Script output streams live on **stdout**. Agent
messages (ask UI, errors, final status) go to **stderr**.

## Try it

```sh
chmod +x ssa
export PATH="/path/to/this/folder:$PATH"
```

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

Batch / no TTY: add `--no-ask`. Keep temp logs: `--keep-temp`.

Run `ssa -h` for full usage. Agent design and style: [AGENTS.md](AGENTS.md).

## Layout

```
ssa/
├── AGENTS.md        # design + style for coding agents
├── LICENSE
├── README.md        # this file
├── ssa              # the agent (single file)
└── oldTests/        # prior test suites (to remake later)
```

## License

MIT — see [LICENSE](LICENSE).
