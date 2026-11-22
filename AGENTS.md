# AGENTS.md

Instructions for coding agents in this repo. Behavior is
in `ssa`. This file is how to work, what stays out, and
the style rules for the shell program.

## This stage

Open work is plan.txt. Change this file in place when a
decision about editing, style, or scope changes. Behavior
changes go in `ssa`. Cite no line numbers.

When a task is done, delete it from plan.txt. Leave the
numbers on the tasks that remain. Renumber only when
asked.

## Layout

One executable, POSIX `sh`, at or under 1000 lines, 80
columns. Edit it in place.

```
ssa
├── AGENTS.md
├── README.md   # help, outside the program
├── plan.txt    # open work
├── ssa         # the program
├── qwen2       # local launcher
├── gemma       # local launcher
└── ds          # local launcher
```

`README.md` is the help. Keep it short: how to run,
environment, one loop paragraph, exit codes. Do not copy
the program into `README.md` beyond what a person needs
to run it. Update `README.md` when a setting's meaning
would otherwise be unclear.

`qwen2`, `gemma`, and `ds` export settings, then call
`ssa`. They are not the product. Do not add flags or
behavior to them. Edit the file to change a setting.

`ssa` takes `-v`, `-y`, `-m`, and `-a`, then the task
words. `-v` sets `SSA_VERBOSE=1`. `-y` sets `SSA_YES=1`.
`-m` sets `SSA_MODEL`. `-a` sets `SSA_AGENT=1`. `--` ends
the flags, so a task can start with a dash. No other
flag. No `-h`.

## The program

`ssa` POSTs an OpenAI-style chat body with `curl` and
reads the reply with `jq`. It needs `curl` and `jq` on
`PATH`. `SSA_MODEL` is required. When that value names a
file, `ssa` also needs `llama-server` and starts it. Any
other model name uses `SSA_URL`. `SSA_KEY` is the bearer
token when the provider needs one.

Each setting is `SSA_` and one word. The on/off settings
are `0` or `1`. Scripts default to on. Edits and chat
default to off. All three at 0 is an error.

The default path is one reply. A script or an edit is
shown, then the menu is `[Y]es [N]o [Q]uit`. The
answers are `y`, `n`, and `q`. Yes runs a script with
`sh -c`. The terminal is its standard input, or
`/dev/null` when there is no terminal. The run returns
that exit code. No asks for a note and sends it as the
next user message. Quit exits 0. `# complete` is an ordinary
comment. There is no prompt limit.

`SSA_AGENT=1` keeps going until `# complete` is the
whole reply, or the last line of a script that exits 0,
or `SSA_PROMPTS` is hit. The default is 20. A value of
0 means no limit. The count applies only on this path.
Yes runs with `/dev/null` as standard input and sends
the output and the exit code back.

A reply is a script when scripts are on and no enabled
marker matches. The markers are `# edit file: PATH` and
`# chat`. With scripts off, a non-marker reply is sent
back as `invalid script` on both paths. On the agent
path, a non-marker reply that `sh -n` rejects is sent
back the same way. `sh -n` accepts a sentence the shell
can run. Do not add a prose check or fence unwrapping.
A bad edit or an empty chat is sent back on both paths,
with no menu. On the default path those retries have no
prompt limit.

There is no `# write`. A model that must create a file
uses a quoted heredoc inside a script.

When `SSA_MODEL` names a file, the server is started
with `--model`, `--alias local`, `--host 127.0.0.1`,
and `--port`, then the words in `SSA_FLAGS`. The
request model name is `local`. An empty `SSA_PORT`
picks `20000 + (pid % 10000)` and tries the next port
up to 10 times. A set port that already answers stops
the run. Do not attach to that server. The server
stops on the way out. Its text goes into the log. With
`SSA_VERBOSE=1` it is also printed.

`SSA_REASONING` sets `reasoning_effort` in the body.
`0`, `off`, or `none` sends `none`. `1` or `on` omits
the field. Any other word is the effort. A server flag
such as `--reasoning off` belongs in `SSA_FLAGS`.
`SSA_JSON` is merged after that field, so its keys
override it. `model` and `messages` from `ssa` still
win. `ssa` reads the reply text only. The raw response
stays in the log. Do not strip a thinking trace, and
do not send a format error for a thinking tag.

A run creates one JSON log. That log cannot be turned
off. The bearer token is not written to the log.
`SSA_KEY` is unset before `sh -c`.

## Real turns

Send the model real system, user, and assistant turns.
Do not flatten a conversation into one message with
markers such as `### user` and `### reply`. Do not put
the system prompt at the head of a user message. Small
models cannot tell these apart, and they answer as if
the transcript were one long question.

This rules out replaying the history in the prompt.
Keep the model loaded and let llama-server hold the
turns, or send a messages array as `ssa` does. A run
that needs a fresh model process for each turn cannot
keep real turns, so it is not an option here.

The end of a turn comes from the harness, not from the
model. Small models do not reliably write a sentinel
such as `# end`. A stop marker the model must remember
is not a boundary; the tool's own prompt or end of
message is.

`# complete` as the last line of a script is not a
boundary. On the agent path it is a shortcut the model
may take after a script exits 0. A model that leaves it
out just gets another turn, so the loop does not depend
on it. On the default path it is a comment.

## Boundaries

Keep the product surface to `ssa`. Help is `README.md`,
outside the program. This repo has no tests. Do not add
`bin/` or `libexec/`. Do not invent flags or env vars
for things the caller's shell can do (`cd`, `export`,
redirects). The only flags are `-v`, `-y`, `-m`, and
`-a`.

`PID` is set once at startup. Do not replace it with
`$$` inside a pipeline subshell.

## File writes

An edit overwrites a file in place, on purpose. The
file keeps its permissions and the rest of its
attributes. A write that stops partway can leave a
partial file. That risk is accepted. Users should keep
backups or filesystem snapshots to recover from it.

## Goals

One goal is a full log of each run. A person or an AI
should be able to read it, debug any problems, and find
better ways to use the program. Keep every record that
review needs. This log is the JSON one from `ssa`.
Script output is kept in memory and written there. Do
not add a temp file for the log or for that output.

Another goal is low token use. Some devices generate
tokens slowly, and a run should stay usable there. Keep
prompts and replies short, and do not add a turn or a
thinking trace the device must generate.

A local model can run with the network off. The files
stay on the machine, and the log stays there too. If
the caller points llama-server at a model over the
network, that is fine too.

The computer should stay responsive while a run is
going. Context size, GPU layers, priority, and sampling
belong in `SSA_FLAGS`, or in a llama-server the caller
started. Do not pick those inside `ssa`. Weights that
are bigger than memory still work, because the weights
stream off the drive.

## Kept out

Kept out of `ssa`: JSON tool calls. A tools array on
the request. A second edit shape (unified diff). Fence
unwrapping. A `# write` marker. A chunk-file compare
protocol. Thinking left on, with the trace stripped
from history. An end-of-run review. Splitting the
program into lib or bin. A second program that starts
the server. A fresh llama-server process on every
turn. A native Windows harness. Capping action output.
Script output is appended in full. A long command can
fill the context. A `-r` flag. A `-h` flag.

`ssa` uses `curl` for the model call. Leave that in
`ssa`.

## Style

Style rules apply to `ssa` unless this section names
one file. Behavior is in the program. `README.md` is
the short help.

### Unix conventions

The program is a Unix-style CLI. When a rule here
conflicts with a well-established Unix or GNU
convention, follow the Unix convention unless this
file documents a deliberate exception.

### Simple words

Readability comes first. Favor plain words of one or
two syllables (`run`, `path`, `script`, `check`,
`setup`). When one short word is not clear enough,
use a longer phrase of short words (`check_can_run`,
`setup_work_folder`).

Prefer long, explicit function names when they
describe the full job. No abbreviations (`argument`
not `arg`, `command` not `cmd`). External tool names
stay as-is (`llama-server`, `curl`, `jq`, `head`,
`sed`).

### Naming

- Variables use `UPPER_CASE` (settings, run state, and locals).
- Functions use `lower_case`.
- User-facing settings use the `SSA_` prefix. Internal run state
  does not.
- Top-level variable blocks (`# Users can set` and `# Internal`)
  keep names alphabetically ordered within each block. Do not
  alphabetize large string constants (prompts) with
  those lists.

Do not shadow top-level variables. Use `$1`, `$2`, or a
different local name inside helpers.

Prefer fewer variables. A value used in one place
should be written there. A function that only fills a
variable for the next line should print the value
instead. Keep a variable when the same fact is read
again later.

### Settings and CLI

Every user-facing setting is an environment variable
(`SSA_*`). Each name is `SSA_` and one word. Document
settings in `README.md`. Internal run state is not a
setting.

`ssa` takes `-v`, `-y`, `-m`, and `-a` before the
task. Those set `SSA_VERBOSE`, `SSA_YES`, `SSA_MODEL`,
and `SSA_AGENT`. `--` ends the flags. Do not add any
other flag.

### Error messages

When the user can fix a failure by changing a
user-facing setting, name the env var.

Skip a hint that names a setting when it would
mislead:

- Internal harness failures (log setup, a bad response).
- Missing OS tools on `PATH` (`llama-server`, `curl`,
  `jq`, `head`, …). Name the tool and say it was not
  found on `PATH`.
- Failures outside the harness (missing model file,
  llama-server exits, `curl` fails).

The task has no env var. Say it was not found on the
CLI.

The opening quote starts on the same line as `die`.
Wrap at 80 columns with adjacent quoted parts.

### Status codes

A predicate used in `if name; then` returns 0 when the
named condition holds and 1 when it does not. Write
the number at the return. Keep predicates pure (no
logging or side effects).

### Functions

- One clear job per function.
- Prefer `if` over `[ test ] && command` when branching among
  actions.
- Guard + `die`: `[ -n "$VAR" ] || die "…"`.
- Guard + `return`: `if [ -z "$VAR" ]; then return; fi`
  (or `return 1`) when that is the whole branch.
  Stay under 80 columns. A longer `then` stays a block.
- `case` arms prefer one line: `pattern) action ;;`.
  Indent each arm 4 spaces from `case`.

### Static strings

Long static text (prompts and errors) lives in
top-level variables, not inside functions. Give a long
sed program a named local. Split fixed text from
substitution. Keep functions thin.

### Line length

Maximum 80 characters per line in `ssa` (code,
comments, static strings). Wrap with `\`, split quoted
strings, or multiple `printf`s. Do not shorten names
just to fit.

### Quoting

Quote string literals in assignments and in `[ ]` / `=`
comparisons. Leave unquoted: numeric constants and
status codes, `case` patterns, signal names in `trap`.

### Streams

- stdout: action and loop output.
- `/dev/tty`: ask UI.
- stderr: harness errors. With `SSA_VERBOSE` at `1`, notes and
  llama-server output too.

### File order

Follow the call graph:

1. Settings, run state, and static strings
2. `main()` first, then callees in call order
3. `main "$@"` on the last line

Each function sits below its last caller. Among callees
of the same caller, keep call order.

### Shell use

Do not add flags or env vars for behavior the caller's
shell can handle in one line at the call site. `-v`,
`-y`, `-m`, and `-a` are the exception. Do not add
flags beyond those.

| Need                    | Shell, not the agent            |
|-------------------------|---------------------------------|
| Working directory       | `cd` before the program         |
| Environment             | `export VAR=value` or `VAR=value ssa …` |
| Diagnostic log file     | `ssa … 2>run.log`               |
| Hung script / open pipe | wrap the program with `timeout` |
| Repeated invalid replies | Ctrl-C, `timeout`, or `ulimit -t` |
| Repeat for many tasks   | `for task in …; do …; done`     |

An invalid script, a bad edit, or an empty chat is
sent back and the loop continues. Do not add a second
count. `ssa` already stops at `SSA_PROMPTS` when
`SSA_AGENT` is 1. llama-server output follows
`SSA_VERBOSE`, so `2>run.log` includes it only with
`-v`.

Ask: could the user do this with `cd`, `export`, or a
redirect? If yes, leave it out of the agent.
