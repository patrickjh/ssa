# ssa

`ssa` is an AI agent harness written as a single POSIX `sh` script.
`ssa` depends only on llama-cli, a few posix shell utils and
a gguf model file on disk, and is hard capped at 1,000 loc.
Inspired by mini-swe agent.

## Run

To run ssa, you must first set the SSA_LLAMA_CLI_ARGUMENTS variable
with at least an -m variable pointing to a gguf model
file somewhere on disk. You can also set any other llama-cli
variables there which will be passed straight to llama-cli.

Put the task for ssa on the command line as args.
Text piped in to stdin is treated as extra context for that task.
Internally, the task gets added as part of the system prompt,
while the text on stdin gets added to the user turn.

```sh
export SSA_LLAMA_CLI_ARGUMENTS="-m /models/gemma.gguf"
cat notes.txt | ssa summarize this file
```

ssa will then work for a while on the task and return when complete.

## response types

Internally, ssa lets the model choose from 5 response types.
1. scripts -> the model returns a shell script that gets run.
2. edits -> the model returns an Aider style edit. These are used to
avoid varioius quoting issues models run into when writing heredocs
to edit files as part of a shell script response.
3. file writes -> the model specifies a file name and returns the raw
new bytes to write to that file. These are also designed to avoid
issues that arise when models try to write files using heredocs as
part of a shell script
4. questions -> the model can ask a question and wait for a response
from the user.
5. response -> the model can just send some text to show the user. Can
be useful if you ask the model to figure something out and tell you the
answer.

So when writing a task for the model to do with ssa, you may want to consider
which of these you are asking for. You can also turn any of these off using
settings covered below.

## Run unattended

By default, ssa will confirm with you step by step before
running a script or editing a file. You can set
`SSA_NO_ASK=1` to run scripts, write files, and edit
files without being asked. You can use this to run ssa for
background or unattended tasks.

## logging

By default, ssa logs what happens in each run to a file.
That file is written inside `SSA_LOG_FOLDER`, which 
defaults to TMPDIR or /tmp. The goal of this logging
is that you or another AI can review what happened in various
runs in order to debug or improve how you are using ssa.
The log file is part of how ssa works, so cannot be disabled.

## output

By default, ssa works like a unix util. This means ssa
works silently and shows nothing on success except output the
model chooses to show you. If you want to see what is going on
in more detail, you can set `SSA_VERBOSE=1`. This will create
a lot of output

## Settings

Set these in the environment. `VAR=value ssa …` covers one
run.

| Setting | Default |
| --- | --- |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, added to the instructions |
| `SSA_LLAMA_CLI_ARGUMENTS` | required; llama-cli flags, including the model |
| `SSA_LOG_FOLDER` | log directory (default `TMPDIR`, or `/tmp`) |
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
