# ssa

`ssa` is one POSIX `sh` program. On Windows, run it under a
POSIX shell such as WSL. It runs a local GGUF through
`llama-cli`, takes a task, and repeats one action per reply
until the model says `# complete`. When `llama-cli` is not
on `PATH`, `ssa` runs `llama cli` after `llama cli --version`
succeeds.

This file is the help. The program has no `-h` or `--help`.

On `PATH`, `ssa` needs `awk`, `cat`, `date`, `grep`, `head`,
`mkdir`, `mkfifo`, `pwd`, `rm`, `sed`, `sh`, `tr`, and `wc`, plus
`llama-cli` or `llama`. The build is the one on `PATH`. The
flags `ssa` adds match current llama.cpp `llama-cli`. An
older build may reject one of them.

A model file on disk needs no network. A flag in
`SSA_LLAMA_CLI_ARGUMENTS` can still make `llama-cli` download
a model or connect to a server.

## Run

Put the task on the command line. The task is part of
the system prompt. The first user turn is the line
`Context from stdin (may be blank):`. When stdin is not a
terminal, those bytes follow that line, after NUL bytes
are removed.

```sh
export SSA_LLAMA_CLI_ARGUMENTS="-m /models/gemma.gguf -c 8192 -n -1"
ssa fix the failing test
cat notes.txt | ssa summarize this repo
```

The program prints no help of its own.

`SSA_NO_ASK=1` runs each script as you, with your
permissions. Writes and edits run the same way. A run
with no terminal stops when `SSA_NO_ASK` is `0`. Set
`SSA_NO_ASK=1` for that run. Questions and messages
are then off. Scripts, writes, and edits still run.

## Loop

Each reply is one action: a shell script, a file write, a
file edit, a question, a message, or `# complete`. A
reply ends on a line that is exactly `# end`. `ssa`
stops reading there. `SSA_NO_SCRIPTS=1` leaves a
write, an edit, a question, a message, or `# complete`.
The run stops when scripts, writes, edits, questions,
and messages are all off. `# complete` alone does not
keep it going. You approve a script, a write, and an
edit unless `SSA_NO_ASK=1`. Answering no asks `reason:`
on `/dev/tty`. A reason is sent to the model with the
rejection when it contains a non-space character. A
question and a message are shown without that approval.
`# complete` needs no approval. The ask text goes to
`/dev/tty` with the answer. A `# question` is shown
there too. The next line is the answer, and a blank
line counts. A `# message` is shown there too, and the
run continues. The terminal bell rings when the ask,
question, or message is ready, and whether a sound
plays depends on the terminal.
A body must not contain a line that is exactly
`# end`. A search or replace line must not be
exactly `=======` or `>>>>>>> REPLACE`. Non-blank
text between `>>>>>>> REPLACE` and `# end` is
rejected.
`SSA_VERBOSE=1` shows progress on
stdout: the log path, llama-cli load text and errors,
each model line, script output, write and edit results,
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
| `SSA_LLAMA_CLI_ARGUMENTS` | unset (required) |
| `SSA_LOG_FOLDER` | temp directory (`TMPDIR`, or `/tmp`) |
| `SSA_NO_ASK` | `0` (ask before a script, write, or edit) |
| `SSA_NO_EDITS` | `0` (allow `# edit file:`) |
| `SSA_NO_MESSAGES` | `0` (allow `# message`) |
| `SSA_NO_QUESTIONS` | `0` (allow `# question`) |
| `SSA_NO_SCRIPTS` | `0` (allow `# script`) |
| `SSA_NO_WRITES` | `0` (allow `# write file:`) |
| `SSA_VERBOSE` | `0` (hide progress) |

The log file stays after exit. Its name is the time, to
the second, then the PID, and `.ssalog`. It is under
`SSA_LOG_FOLDER`. With `SSA_VERBOSE=1`, the path is
printed at the start and again before the done line.
A failure prints the path on stderr after the error.
If llama-cli exits, the die message says so.
The log starts with the time and the directory, then
the llama-cli version and each `SSA_*` value. The
flags are only the `SSA_LLAMA_CLI_ARGUMENTS` line.
The next block is the system prompt. The main
process writes the end time and the status, and
exits without waiting on llama-cli.
`# llama-cli stderr` is appended when llama-cli
exits. On a completed run that block follows
the status line. When llama-cli exits early,
the block can come first.
NUL bytes in stdin and in script output are removed
before they are logged. An edit fails when the file
contains a NUL.

`SSA_LLAMA_CLI_ARGUMENTS` is the caller's `llama-cli` flags,
including `-m` or `--model`, plus any of `-c`, `-n`,
`--context-shift`, and `--keep`. The run stops when
neither `-m` nor `--model` is its own word with a path
after it. The value is split on the shell IFS (spaces,
tabs, and newlines unless `IFS` was changed). A quote
in the value is an ordinary character, so a path with a
space does not work. A finite `-n`, `--predict`, or
`--n-predict` can end the reply before a line that is
exactly `# end`. `ssa` keeps reading for that line, and
`llama-cli` waits for the next user turn, so the run
hangs. Pass `-n -1`, or a limit long enough that the
reply includes `# end`.

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
flags, ssa passes `--reverse-prompt` so generation
stops after a line that is exactly `# end`. A
caller's `-r` or `--reverse-prompt` stays in effect
too. llama-cli stops at the first match. When that
match is not a line that is exactly `# end`, `ssa`
keeps reading for that line and the run hangs. Do
not pass `-r` or `--reverse-prompt`.

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or user quit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.
