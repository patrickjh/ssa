# ssa

`ssa` is a POSIX `sh` program. On Windows, run it under a
POSIX shell such as WSL. It gives a task to a local model
through `llama-cli` and repeats until the task is done.
If `llama-cli` is not installed, it uses the `llama`
command. A model file on disk needs no network. This
file is the help. The program has no `-h` or `--help`.

## Run

Put the task on the command line. Text piped in is extra
context for that task.

```sh
export SSA_LLAMA_CLI_ARGUMENTS="-m /models/gemma.gguf -c 8192 -n -1"
ssa fix the failing test
cat notes.txt | ssa summarize this repo
```

`SSA_LLAMA_CLI_ARGUMENTS` must include `-m` or `--model`
and a model path. A path with a space does not work.
Give the model enough room to finish each reply. A short
reply limit can leave the run waiting.

`SSA_NO_ASK=1` runs scripts, writes, and edits without
asking. A run with no terminal needs that setting.
Questions and messages are then off.

## Loop

Each turn the model does one thing: run a script, write
a file, edit a file, ask a question, or show a message.
You approve a script, a write, and an edit unless
`SSA_NO_ASK=1`. A question or a message is shown without
that approval. The run ends when the model finishes the
task, or when scripts, writes, edits, questions, and
messages are all turned off.

One log file is written per run, under `SSA_LOG_FOLDER`,
and it stays after exit. `SSA_VERBOSE=1` shows progress
and the log path. A failure prints the log path on
stderr.

## Settings

Set these in the environment. `VAR=value ssa …` covers one
run.

| Setting | Default |
| --- | --- |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, added to the instructions |
| `SSA_LLAMA_CLI_ARGUMENTS` | required; llama-cli flags, including the model |
| `SSA_LOG_FOLDER` | temp directory (`TMPDIR`, or `/tmp`) |
| `SSA_NO_ASK` | `0` (ask before a script, write, or edit) |
| `SSA_NO_EDITS` | `0` (allow file edits) |
| `SSA_NO_MESSAGES` | `0` (allow messages) |
| `SSA_NO_QUESTIONS` | `0` (allow questions) |
| `SSA_NO_SCRIPTS` | `0` (allow scripts) |
| `SSA_NO_WRITES` | `0` (allow file writes) |
| `SSA_VERBOSE` | `0` (hide progress) |

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or user quit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.
