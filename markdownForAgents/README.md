# Simple Shell Agent (ssa)

Simple Shell Agent (`ssa`) is a simple AI coding agent written in mostly POSIX `sh`. Inspired by [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent): give the model **only shell**, run each step in a **fresh process**, keep a **simple loop**.

**Models.** Inference is pluggable via "model runners": executable files that read the full prompt on `stdin`, send it to a backend, and write the model response as plain text on `stdout`. Two bundled runners live in [libexec/ssa/](../libexec/ssa/): OpenAI-compatible HTTP ([curlRunner.sh](../libexec/ssa/curlRunner.sh)) and local llama.cpp ([llamaCppRunner.sh](../libexec/ssa/llamaCppRunner.sh)). Set `--model-runner` or `SSA_MODEL_RUNNER` to the full path of one of those scripts, or to your own runner (`chmod +x` required). Runners should use `stderr` only for errors, not model text. Exit `0` on success. Exit non-zero to retry the same prompt and conversation transcript after a transient error. Call `util_die` (SIGUSR1 to `ssa`) to stop the agent on unrecoverable errors. Set `-m` or `SSA_MODEL` to identify which model to use; each runner interprets `SSA_MODEL` for its backend (`SSA_MODEL` is a GGUF path for llamaCppRunner, a model name for curlRunner).

**Unix-shaped.** Invoke `ssa` like `curl` or `make`: handle `cd`, env, redirects and so on with the shell. `ssa` just runs shell scripts sent by the AI model in the current working directory using an agent loop. Output from running these shell scripts is streamed live to **stdout** (stdout and stderr interleaved) and copied into the transcript for the model in the same order. `ssa` messages (errors, final status) go to **stderr**. Errors from prompting the models also go to stderr.

**Script runners.** By default model scripts run in a fresh subshell as your user, which can be unsafe. Point `--script-runner` or `SSA_SCRIPT_RUNNER` at an executable helper to control how scripts run. Bundled script runners in [libexec/ssa/](../libexec/ssa/): ask the user first ([askUserSandbox.sh](../libexec/ssa/askUserSandbox.sh)) and Unix-user isolation ([switchUserSandbox.sh](../libexec/ssa/switchUserSandbox.sh)). You can use your own executable. Script runners receive the model's script on stdin and run it with separate stdout and stderr; the harness merges both for the transcript. Runner diagnostics may go to stderr.

**Command name.** Add [bin/](../bin/) to your `PATH` and run `ssa` ([bin/ssa](../bin/ssa) execs [libexec/ssa/ssa.sh](../libexec/ssa/ssa.sh)). Set `SSA_MODEL_RUNNER` to the full path of a runner under `libexec/ssa/` (or your own path). Harness settings use the `SSA_` prefix. On some HPE server installs, `ssa` may already mean HPE Smart Storage Administrator; run `command -v ssa` before adding this project to your `PATH`, or invoke by full path.

**Session logs.** We write extensive logs under `${TMPDIR:-/tmp}/ssa-$LOGNAME-<timestamp>/`. For speed, point `TMPDIR` at a tmpfs (e.g. `/dev/shm` on Linux). For durability and debugging, point `TMPDIR` at durable storage and pass `--keep-session` or set `SSA_KEEP_SESSION=1` to keep the folder after exit. See [DESIGN.md](DESIGN.md) for file names.

## Layout

```
ssa/
├── README.md                    # short human-oriented intro
├── bin/
│   └── ssa                      # add this directory to PATH
├── libexec/
│   └── ssa/                     # implementation (not on PATH)
│       ├── ssa.sh               # agent harness
│       ├── utils.sh             # shared helpers
│       ├── curlRunner.sh        # OpenAI-compatible HTTP API
│       ├── llamaCppRunner.sh    # local llama.cpp
│       ├── askUserSandbox.sh    # show script on stderr, approve on /dev/tty
│       └── switchUserSandbox.sh # run scripts as another Unix user
└── markdownForAgents/           # design and style docs for contributors
    ├── README.md                # this file
    ├── DESIGN.md
    └── STYLE.md
```

## Try it

Add `bin/` to your `PATH` (adjust to where you cloned or downloaded the repo):

```sh
export PATH="/path/to/ssa/bin:$PATH"
```

### curlRunner (OpenAI-compatible HTTP)

Using environment variables:

```sh
export OPENAI_API_KEY="sk-..."
export OPENAI_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL_RUNNER="/path/to/ssa/libexec/ssa/curlRunner.sh"
export SSA_MODEL=gpt-4o-mini
ssa summarize this repo
```

Using CLI flags (runner env still required for the API key and URL):

```sh
export OPENAI_API_KEY="sk-..."
export OPENAI_URL="https://api.openai.com/v1/chat/completions"
ssa --model-runner "/path/to/ssa/libexec/ssa/curlRunner.sh" \
  -m gpt-4o-mini summarize this repo
```

### llamaCppRunner (local llama.cpp)

Using environment variables:

```sh
export SSA_MODEL_RUNNER="/path/to/ssa/libexec/ssa/llamaCppRunner.sh"
export SSA_MODEL=/path/to/model.gguf
export LLAMA_CPP_ARGS="--context 8192 --temp 0.7"   # optional
ssa summarize this repo
```

Using CLI flags:

```sh
ssa --model-runner "/path/to/ssa/libexec/ssa/llamaCppRunner.sh" \
  -m /path/to/model.gguf summarize this repo
```

Task on stdin instead of argv:

```sh
echo "summarize this repo" | ssa \
  --model-runner "/path/to/ssa/libexec/ssa/curlRunner.sh" -m gpt-4o-mini
```

Run `ssa -h` for full usage (source: `HELP_TEXT` in [libexec/ssa/ssa.sh](../libexec/ssa/ssa.sh)). How it works and project rules: [DESIGN.md](DESIGN.md). Coding style: [STYLE.md](STYLE.md).

## License

MIT — see [LICENSE](../LICENSE).
