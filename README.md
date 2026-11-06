# ssa

This repo has three AI agent harnesses. Each one is a single POSIX
`sh` script. Each takes the task as arguments and extra context on
stdin. Inspired by mini-swe-agent.

| File | How it reaches a model |
| --- | --- |
| `ssa` | `curl` and `jq`, to a chat-completions URL |
| `ssa-local` | `llama-cli`, with a GGUF file on disk |
| `ssa-simple` | `llama-cli`; a script or `# complete` |

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

Needs `llama-cli` or `llama` on `PATH`, and a GGUF file on disk.
Set `SSA_LLAMA_CLI_ARGUMENTS` with at least `-m` or `--model`
pointing at that file. Other llama-cli flags in that variable
are passed through. This program has no `-h`. This file is the
help.

The task is part of the system prompt. Text on stdin is added
to the user turn.

```sh
export SSA_LLAMA_CLI_ARGUMENTS="-m /models/gemma.gguf"
cat notes.txt | ssa-local summarize this file
```

The model returns one script, write, edit, question, or
message. A script is run. A write or an edit changes a file.
A question waits for an answer. A message is text for the
user. Any of these can be turned off with the settings below.

ssa-local asks before a script, write, or edit.
`SSA_ASSUME_YES=1` skips the question, for a background run.

Each run writes one log file in `SSA_LOG_FOLDER` (default
`TMPDIR`, or `/tmp`). The log stays. It cannot be turned off.

With `SSA_VERBOSE=0` (the default), a run is quiet aside from
output the model chooses to show. `SSA_VERBOSE=1` prints
progress.

### Settings

Set these in the environment. `VAR=value ssa-local …` covers
one run.

| Setting | Default |
| --- | --- |
| `SSA_ASSUME_YES` | `0` (ask before a script, write, or edit) |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, added to the instructions |
| `SSA_LLAMA_CLI_ARGUMENTS` | required; llama-cli flags, including the model |
| `SSA_LOG_FOLDER` | log directory (default `TMPDIR`, or `/tmp`) |
| `SSA_NO_EDITS` | `0` (allow file edits) |
| `SSA_NO_MESSAGES` | `0` (allow messages) |
| `SSA_NO_QUESTIONS` | `0` (allow questions) |
| `SSA_NO_SCRIPTS` | `0` (allow scripts) |
| `SSA_NO_WRITES` | `0` (allow file writes) |
| `SSA_VERBOSE` | `0` (hide progress) |

### Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or user quit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.

## ssa-simple

Needs `llama-cli` or `llama` on `PATH`. `SSA_MODEL_FILE` is
the path to a GGUF file. `-m` sets the path for one run.
`-y` sets `SSA_ASSUME_YES=1`. `-v` sets `SSA_VERBOSE=1`. Options
come before the task. `--` ends them. A flag wins over the
environment. This program has no `-h`. This file is the
help.

The task is part of the system prompt. Text on stdin is added
to the user turn.

```sh
cat notes.txt | ssa-simple -y -v -m /models/gemma.gguf summarize this file
```

The model returns one script. The script is the whole reply.
ssa-simple runs it and sends the output back. Every reply
ends with a line that is exactly `# end`. A line that is
exactly `# complete` ends the run. It sits above `# end`.
The script above `# complete` is run, then the run stops.
A line of comments may sit above `# complete`.

Lines between `<think>` and `</think>`, and between
`[Start thinking]` and `[End thinking]`, are stored as `#`
comments. A `# complete` line there does not end the run.
A `# end` line there ends the reply.

ssa-simple asks before a script. `SSA_ASSUME_YES=1` skips the
question, for a background run.

A run does not write a log file.

With `SSA_VERBOSE=0` (the default), a run is quiet aside from
output the model chooses to show. `SSA_VERBOSE=1` prints
progress.

### Settings

Set these in the environment. `VAR=value ssa-simple …` covers
one run.

| Setting | Default |
| --- | --- |
| `SSA_ASSUME_YES` | `0` (ask before a script). `-y` sets `1` |
| `SSA_MODEL_FILE` | required; GGUF path. `-m` sets it |
| `SSA_VERBOSE` | `0` (hide progress). `-v` sets `1` |

### Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or user quit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.
