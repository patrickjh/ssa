# ssa

`ssa` is one POSIX `sh` program. On Windows, run it under a
POSIX shell such as WSL. It runs a local GGUF through
`llama-cli`, takes a task, and repeats one action per reply
until the model says `# complete`. When `llama-cli` is not
on `PATH`, `ssa` runs `llama cli` after `llama cli --version`
succeeds.

This file is the help. The program has no `-h` or `--help`.

## Run

Put the task on the command line. The task is part of
the system prompt. The first user turn is the line
`Context from stdin (may be blank):`. When stdin is not a terminal,
those bytes follow that line.

```sh
export SSA_LLAMA_CLI_ARGS="-m /models/gemma.gguf -c 8192 -n 8192"
ssa fix the failing test
cat notes.txt | ssa summarize this repo
```

The program prints no help of its own.

A run with no terminal sets `SSA_NO_ASK=1`.

## Loop

Each reply is one action: a shell script, a file write, a
file edit, a question, or `# complete`. A reply ends on
a line that is exactly `# end`, and text after that line
is rejected. `SSA_NO_SCRIPTS=1` leaves a write, an edit,
or `# complete`. You approve each action
unless `SSA_NO_ASK=1`. The ask text goes to `/dev/tty`
with the answer. A `# question` is shown there too. The
next line is the answer, and a blank line counts.
`SSA_VERBOSE=1` shows progress on
stdout: the log path, llama-cli load text, each model
line, script output, write and edit results,
rejections, format errors, and the done line. Script
output is printed after the command exits.
`SSA_VERBOSE=0` shows none of that. stderr is harness
errors. A failure prints the log path there after the
error.

## Settings

Set these in the environment. `VAR=value ssa …` covers one
run.

| Setting | Default |
| --- | --- |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, appended to the system prompt |
| `SSA_LLAMA_CLI_ARGS` | unset (required) |
| `SSA_LOG_FOLDER` | temp directory (`TMPDIR`, or `/tmp`) |
| `SSA_NO_ASK` | `0` (ask before each action) |
| `SSA_NO_EDITS` | `0` (allow `# edit file:`) |
| `SSA_NO_SCRIPTS` | `0` (allow `# script`) |
| `SSA_NO_WRITES` | `0` (allow `# write file:`) |
| `SSA_VERBOSE` | `0` (hide progress) |

The log file stays after exit. Its name is the time, to
the second, then the PID, and `.ssalog`. It is under
`SSA_LOG_FOLDER`. With `SSA_VERBOSE=1`, the path is
printed at the start and again before the done line.
A failure prints the path on stderr after the error.
If llama-cli exits, the die message says so.

`SSA_LLAMA_CLI_ARGS` is the caller's `llama-cli` flags,
including `-m` or `--model`, plus any of `-c`, `-n`,
`--context-shift`, and `--keep`. The run stops when
neither `-m` nor `--model` is its own word with a path
after it. Flags are split on spaces, so a path with a
space does not work. A short `-n` can stop the reply
before `# end`, and ssa waits for that line.

`ssa` puts these flags in front of that string:
`--reasoning off`, `--reasoning-budget 0`,
`--simple-io`, `--no-display-prompt`,
`--no-show-timings`, `--color off`, `--context-shift`,
and `--keep -1`. It passes `-sys` with the system
prompt before those flags. A later flag replaces an
earlier one when `llama-cli` has a second form.
`--context-shift` and `--keep -1` keep that prompt,
including the task, and drop older tokens after it
when the context fills. `--simple-io` has no off
flag. Do not pass `--multiline-input`.
Each line ssa sends ends in a backslash, and that
flag ends the message there. After the caller's
flags, ssa passes `--reverse-prompt`. Generation
stops after a line that is exactly `# end`. This
flag is last, so a caller's `-r` does not replace
it.

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or user quit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.
