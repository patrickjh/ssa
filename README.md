# ssa

This repo has two AI agent harnesses. Each one is a single POSIX
`sh` script. Flags may come first. The other arguments are the
task, and extra context is on stdin. Inspired by mini-swe-agent.

| File | How it reaches a model |
| --- | --- |
| `ssa` | `curl` and `jq`, to a chat-completions URL |
| `ssa-local` | starts `llama-server`, then runs `ssa` at it |

## ssa

Needs `curl` and `jq` on `PATH`. `SSA_URL` and `SSA_MODEL` are
required. Set `SSA_KEY` when the provider needs a bearer token.
This file is the help.

```sh
export SSA_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL=gpt-4o-mini
export SSA_KEY="sk-..."
cat notes.txt | ssa summarize this file
```

`-v`, `-y`, and `-m` may come before the task. `-v` sets
`SSA_VERBOSE=1` and prints short notes on stderr. `-y` sets
`SSA_ASSUME_YES=1`. `-m` sets `SSA_MODEL` to the next word. `--`
ends the flags, so a task can start with a dash.

The task is part of the system prompt. Text on stdin is the
first user turn. With no stdin, that turn says no context was
given.

The model returns one POSIX `sh` program. ssa runs it and sends
back the output and exit code. When a style below is turned on, a
reply whose first marker line is `# write file: …`, `# edit file:
…`, or `# chat` does that instead. A chat shows the text and reads
one line. An empty line is sent back as "The user sent no text."
This repeats until the model returns `# complete` as the whole
reply, or as the last line of a script that exited 0, or until
`SSA_MAX_MODEL_PROMPTS` is hit.

ssa asks before a script, write, or edit. `SSA_ASSUME_YES=1` skips
the question.

Each run writes one JSON log in `SSA_LOG_FOLDER` (default
`TMPDIR`, or `/tmp`). The log stays. It cannot be turned off.

### Settings

Set these in the environment. `VAR=value ssa …` covers one run.

| Setting | Default |
| --- | --- |
| `SSA_ASSUME_YES` | `0` (ask before a script, write, or edit) |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, added to the instructions |
| `SSA_KEY` | empty; bearer token when the provider needs one |
| `SSA_LOG_FOLDER` | log directory (default `TMPDIR`, or `/tmp`) |
| `SSA_MAX_CONTEXT_BYTES` | `0` (send every turn) |
| `SSA_MAX_MODEL_PROMPTS` | `20` (`0` means no limit) |
| `SSA_MODEL` | required; model name |
| `SSA_NO_CHAT` | `0` (a `# chat` reply is a chat) |
| `SSA_NO_EDITS` | `0` (a `# edit file: …` reply is an edit) |
| `SSA_NO_SCRIPTS` | `0` (a reply is a script) |
| `SSA_NO_WRITES` | `0` (a `# write file: …` reply is a write) |
| `SSA_REQUEST_JSON` | empty; extra JSON object merged into the body |
| `SSA_URL` | required; URL curl POSTs to |
| `SSA_VERBOSE` | `0` (no extra notes on stderr) |

`SSA_REQUEST_JSON` is where `think`, `max_tokens`, and sampling
go. On a key conflict, `model` and `messages` from ssa win.

Turning a style off makes its marker an ordinary comment inside
the script. So `SSA_NO_WRITES=1` runs a reply that starts with
`# write file: notes.txt` as a script, and it writes nothing.

### Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or the prompt limit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.

## ssa-local

Needs `llama-server`, `curl`, and `ssa` on `PATH`, plus a GGUF
file on disk. `SSA_MODEL_FILE` is the path to that file. `-m`
sets that path for one run. `-v` and `-y` mean the same as they
do for `ssa`. This program has no `-h`. This file is the help.

ssa-local starts `llama-server` on `127.0.0.1`, waits for
`/health` to answer, runs `ssa` at that server, then stops the
server. The chat is ssa's own, so the log, the prompt limit, and
the ask-before-acting question all work as they do under `ssa`.

```sh
export SSA_MODEL_FILE=/models/gemma.gguf
cat notes.txt | ssa-local summarize this file
```

The server is given four flags and nothing else: `--model` with
the path in `SSA_MODEL_FILE`, `--alias local`, `--host 127.0.0.1`,
and `--port` with `SSA_SERVER_PORT`. Context size, GPU layers,
thread priority, and sampling are whatever `llama-server` does by
default. Change them in that program or start `llama-server`
yourself and use `ssa`.

The alias `local` goes to `ssa` as `SSA_MODEL`. If the port
already answers, the run stops instead of using that server.

ssa-local turns the write, edit, and chat reply shapes off by
default, because a local model does best with one shape. Each is
still a setting, so `SSA_NO_WRITES=0 ssa-local …` turns one back
on. Scripts and `# complete` are always available.

`llama-server` prints its load messages to stderr. Redirect stderr
to hide them:

```sh
ssa-local summarize this file 2>/dev/null
```

The run writes one log: the JSON log from `ssa`, in
`SSA_LOG_FOLDER` (default `TMPDIR`, or `/tmp`). It stays. It
cannot be turned off. ssa-local writes no log of its own.

ssa-local prints nothing of its own unless `-v` or
`SSA_VERBOSE=1`. A model load can take a while with stderr
silenced, so keep stderr open if you want to watch it start.

### Settings

Set these in the environment. `VAR=value ssa-local …` covers
one run. Every setting `ssa` reads still applies, since ssa-local
runs `ssa`, and text on stdin reaches `ssa` too.

| Setting | Default |
| --- | --- |
| `SSA_MODEL_FILE` | required; path to the GGUF file |
| `SSA_SERVER_PORT` | `8080`; port for the local server |
| `SSA_SERVER_WAIT` | `120`; seconds to wait for `/health` |

### Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, or the server did not start |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line. The others
are `ssa`'s own where `ssa` was reached.
