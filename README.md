# ssa

One POSIX `sh` script. Flags may come first. The other
arguments are the task, and extra context is on stdin.
This file is the help. There is no `-h`.

Needs `curl` and `jq` on `PATH`. When `SSA_MODEL` names
a file, it also needs `llama-server`.

## Run

A model name uses `SSA_URL`. Set `SSA_KEY` when the
provider needs a bearer token.

```sh
export SSA_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL=gpt-4o-mini
export SSA_KEY="sk-..."
cat notes.txt | ssa summarize this file
```

A model file starts `llama-server` on `127.0.0.1` and
talks to it as the model name `local`. The server stops
on the way out.

```sh
export SSA_MODEL=/models/gemma.gguf
ssa summarize this folder
```

`-v` sets `SSA_VERBOSE=1`. `-y` sets `SSA_YES=1`. `-m`
sets `SSA_MODEL` to the next word. `-a` sets
`SSA_AGENT=1`. `--` ends the flags, so a task can start
with a dash.

`qwen2`, `gemma`, and `ds` export settings for one
model, then call `ssa`. Their arguments are ssa's. Edit
the file to change a setting.

## One turn, or an agent

The task is part of the system text. The first user
turn is the operating system, the current directory,
and any text from stdin. A terminal on stdin adds no
extra text.

`SSA_AGENT` defaults to 0. ssa shows the reply and asks

    Apply this? [Y]es [F]eedback [Q]uit

The answers are `y`, `f`, and `q`. Yes runs a script
with `sh -c`. The terminal is its standard input, or
`/dev/null` when there is no terminal. Output is shown
when the script exits, including a prompt the script
printed. The run returns that exit code. Feedback sends
the note as the next user message and asks again. An
empty note is "The user sent no text." Quit ends the
run. `# complete` is an ordinary comment. There is no
prompt limit.

`-a` or `SSA_AGENT=1` keeps going until `# complete` is
the whole reply, or the last line of a script that
exits 0, or `SSA_PROMPTS` is hit. Yes runs with
`/dev/null` as standard input. The output and the exit
code go back to the model. `SSA_PROMPTS` defaults to
20. `0` means no limit. The count applies only when the
agent is on.

## Shapes

`SSA_SCRIPTS`, `SSA_EDITS`, and `SSA_CHAT` are `1` or
`0`. Scripts default to on. Edits and chat default to
off. All three at 0 is an error. A shape that is off
leaves its marker as an ordinary comment.

```
# edit file: PATH
# chat
```

A reply is a script when scripts are on and no enabled
marker matches. With scripts off, that reply is sent
back as `invalid script` and ssa tries again. On the
default path that retry has no prompt limit.

An edit needs a file that already exists, one non-empty
search block, and one match. A bad edit or an empty
chat is sent back. ssa prints the error and the reply,
then tries again. On the default path that retry has no
prompt limit and no menu.

A chat is shown and one line is read. An empty line is
sent back as "The user sent no text." `SSA_YES` skips
the question for a script or an edit. It does not skip
a chat. With no terminal, set `SSA_YES=1`. That also
turns chat off.

## Settings

`VAR=value ssa …` covers one run. Each name is `SSA_`
and one word.

| Setting | Default |
| --- | --- |
| `SSA_AGENT` | `0` |
| `SSA_CHAT` | `0` |
| `SSA_EDITS` | `0` |
| `SSA_EXTRA` | empty; text after the reply rules, before the task |
| `SSA_FLAGS` | empty; extra `llama-server` words |
| `SSA_JSON` | empty; JSON object merged into the body |
| `SSA_KEY` | empty; bearer token, not written to the log |
| `SSA_LIMIT` | `400000` characters (`0` sends every turn) |
| `SSA_LOGS` | `TMPDIR`, or `/tmp` |
| `SSA_MODEL` | required; a file starts the local server |
| `SSA_PORT` | empty; pick a high port |
| `SSA_PROMPTS` | `20` (`0` means no limit; agent only) |
| `SSA_REASONING` | `0` |
| `SSA_SCRIPTS` | `1` |
| `SSA_URL` | required when `SSA_MODEL` is not a file |
| `SSA_VERBOSE` | `0` |
| `SSA_WAIT` | `120` seconds for `/health` |
| `SSA_YES` | `0` |

`SSA_REASONING`: `0`, `off`, or `none` sends
`reasoning_effort` none. `1` or `on` omits the field.
Any other word is the effort, such as `low` or `high`.
Empty is an error. A server flag such as
`--reasoning off` belongs in `SSA_FLAGS`.

`SSA_JSON` is merged after `reasoning_effort`. Its keys
override that field. `model` and `messages` from ssa
still win. A value that is not an object is an error.

`SSA_LIMIT` counts characters. The system text and the
first user turn stay. Older pairs drop until the send
fits. A single message that is still over the limit
goes out as it is.

The local server is started with `--model`,
`--alias local`, `--host 127.0.0.1`, and `--port`,
then the words in `SSA_FLAGS`. An empty `SSA_PORT`
picks `20000` plus the process id modulo `10000`, and
tries the next port up to 10 times. A set port that
already answers stops the run. Server text goes into
the log. With `SSA_VERBOSE=1` it is also printed.

Each run writes one JSON log in `SSA_LOGS`. The log
stays. It cannot be turned off.

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task is done, or the person quits. Yes on the default path returns the script or action exit code |
| 1 | Bad arguments, a harness failure, the server did not start, or the prompt limit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.
