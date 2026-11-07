# ssa

This repo has two AI agent harnesses. Each one is a single POSIX
`sh` script. Each takes the task as arguments and extra context on
stdin. Inspired by mini-swe-agent.

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

The task is part of the system prompt. Text on stdin is the
first user turn. With no stdin, that turn says no context was
given.

The model returns one script, write, edit, question, or
message. ssa runs a script, write, or edit, shows a question
and sends the answer back, or shows a message and keeps going.
This repeats until the model returns `# complete`, or until
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
| `SSA_NO_EDITS` | `0` (allow file edits) |
| `SSA_NO_MESSAGES` | `0` (allow messages) |
| `SSA_NO_QUESTIONS` | `0` (allow questions) |
| `SSA_NO_SCRIPTS` | `0` (allow scripts) |
| `SSA_NO_WRITES` | `0` (allow file writes) |
| `SSA_REQUEST_JSON` | empty; extra JSON object merged into the body |
| `SSA_URL` | required; URL curl POSTs to |

`SSA_REQUEST_JSON` is where `think`, `max_tokens`, and sampling
go. On a key conflict, `model` and `messages` from ssa win.

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
file on disk. `SSA_MODEL_FILE` is the path to that file. This
program has no `-h`. This file is the help.

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

`llama-server` prints its load messages to stderr, even when
`SSA_VERBOSE` is `0`. Redirect stderr to hide them:

```sh
ssa-local summarize this file 2>/dev/null
```

The run writes one log: the JSON log from `ssa`, in
`SSA_LOG_FOLDER` (default `TMPDIR`, or `/tmp`). It stays. It
cannot be turned off. ssa-local writes no log of its own.

With `SSA_VERBOSE=0` (the default), a run is quiet aside from
output the model chooses to show. `SSA_VERBOSE=1` prints progress.

### Settings

Set these in the environment. `VAR=value ssa-local …` covers
one run. Every setting `ssa` reads still applies, since ssa-local
runs `ssa`, and text on stdin reaches `ssa` too.

| Setting | Default |
| --- | --- |
| `SSA_MODEL_FILE` | required; path to the GGUF file |
| `SSA_SERVER_PORT` | `8080`; port for the local server |
| `SSA_SERVER_WAIT` | `120`; seconds to wait for `/health` |
| `SSA_VERBOSE` | `0` (hide progress) |

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
