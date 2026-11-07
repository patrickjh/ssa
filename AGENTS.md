# AGENTS.md

Instructions for coding agents in this repo. Behavior is
in `ssa` and `ssa-local`. This file is how to work, what
stays out, and the style rules for the shell programs.

## This stage

Open work is plan.txt. Change this file in place when a
decision about editing, style, or scope changes. Behavior
changes go in the program they belong to. Cite no line numbers.

When a task is done, delete it from plan.txt. Leave the
numbers on the tasks that remain. Renumber only when
asked.

## Layout

Two executables, each POSIX `sh`, at or under 1000 lines,
80 columns. Edit each file in place.

```
ssa
├── AGENTS.md
├── README.md      # help, outside the programs
├── plan.txt       # open work
├── ssa            # curl and jq; chat-completions URL
└── ssa-local      # llama-server, then ssa at that server
```

`README.md` is the help for both. Keep it short: how to
run, environment, one loop paragraph, exit codes. Do not copy
a program into `README.md` beyond what a person needs to run
it. Update `README.md` when a setting's meaning would otherwise
be unclear.

Neither program has flags. The words on the command line are
the task.

## The programs

`ssa` POSTs an OpenAI-style chat body to `SSA_URL` with `curl`
and reads the reply with `jq`. It needs `curl` and `jq` on
`PATH`. Required settings are `SSA_URL` and `SSA_MODEL`.
`SSA_KEY` is the bearer token when the provider needs one.

A turn is a script, a write, an edit, a question, or a message.
The loop stops on `# complete` or `SSA_MAX_MODEL_PROMPTS`. A run
creates one JSON log. That log cannot be turned off. The bearer
token is not written to the log.

`ssa-local` starts `llama-server` on `127.0.0.1`, waits on
`/health`, runs `ssa` at that server, then stops the server.
It needs `llama-server`, `curl`, and `ssa` on `PATH`, and a
GGUF file named in `SSA_MODEL_FILE`. The network can stay off.

The server gets four flags and nothing else: `--model`,
`--alias local`, `--host 127.0.0.1`, `--port`. The alias is
the `SSA_MODEL` that `ssa` receives, and the port is
`SSA_SERVER_PORT`, so the address and the name cannot drift
from what `ssa` is told. Every other llama-server option stays
at its default. A caller who needs context size, GPU layers,
priority, or sampling changes them in llama-server, or starts
the server and uses `ssa` on it. Do not add a variable that
forwards llama-server flags.

The chat is `ssa`'s, so the turn shape, the log, and the
prompt limit are `ssa`'s too. `ssa-local` writes no log: the
run writes one log, the JSON one from `ssa`. llama-server
prints to stderr, which is where a harness diagnostic goes.

Neither program passes a reasoning flag. The model and its
chat template decide. `ssa` sends a format error when a reply
carries a thinking tag, so a model that thinks inside its
content sees that error and tries again.

## Real turns

Every program must send the model real system, user, and
assistant turns. Do not flatten a conversation into one
message with markers such as `### user` and `### reply`.
Do not put the system prompt at the head of a user message.
Small models cannot tell these apart, and they answer as
if the transcript were one long question.

This rules out replaying the history in the prompt. Keep the
model loaded and let llama-server hold the turns, or send a
messages array as `ssa` does. A run that needs a fresh model
process for each turn cannot keep real turns, so it is not
an option here.

The end of a turn comes from the harness, not from the model.
Small models do not reliably write a sentinel such as
`# end`. A stop marker the model must remember is not a
boundary; the tool's own prompt or end of message is.

## Boundaries

Keep the product surface to these two executables. Help is
`README.md`, outside the programs. This repo has no tests.
Do not add `bin/` or `libexec/`. Do not invent flags or env vars
for things the caller's shell can do (`cd`, `export`, redirects).
Neither program takes a flag.

`PID` is set once at startup. Do not replace it with `$$`
inside a pipeline subshell.

## File writes

Overwrite a file in place, on purpose. The file keeps its
permissions and the rest of its attributes. A write that
stops partway can leave a partial file. That risk is
accepted. Users should keep backups or filesystem
snapshots to recover from it.

## Goals

One goal is a full log of each run. A person or an AI
should be able to read it, debug any problems, and find
better ways to use the program. Keep every record that
review needs. This log is the JSON one from `ssa`, and
`ssa-local` gets it by running `ssa`. `ssa-local` writes no
log of its own.

Another goal is low token use. Some devices generate
tokens slowly, and a run should stay usable there. Keep
prompts and replies short, and do not add a turn or a
thinking trace the device must generate.

`ssa-local` can run with no network. The files stay on the
machine, and the log stays there too. A local model works
with the network off. If the caller points llama-server at
a model over the network, that is fine too.

The computer should stay responsive while a run is going.
llama-server has flags for priority and polling, and context
size, GPU layers, and sampling. This repo sets none of them.
A caller who needs one starts llama-server with that flag and
runs `ssa` at it. Weights that are bigger than memory still
work that way, because the weights stream off the drive. Pass
a llama-server flag only in that caller's own command line,
never in these programs.

## Kept out

Kept out of the shell programs: JSON tool calls. A tools
array on the request. A second edit shape (unified diff).
Fence unwrapping. A chunk-file compare protocol. Thinking
left on, with the trace stripped from history. An
end-of-run review. Splitting a program into lib or bin. A
native Windows harness. Capping action output. Script
output is appended in full. A long command can fill the
context.

Kept out of `ssa-local`: an HTTP client for a model server.
A fresh llama-server process on every turn. A variable that
forwards llama-server flags.

`ssa` uses `curl` for the model call. Leave that in `ssa`.
Do not add it to `ssa-local`.

## Style

Style rules apply to the shell programs unless this section
names one file. Behavior is in the program. `README.md` is
the short help.

### Unix conventions

The programs are Unix-style CLIs. When a rule here conflicts
with a well-established Unix or GNU convention, follow the Unix
convention unless this file documents a deliberate exception.

### Simple words

Readability comes first. Favor plain words of one or two
syllables (`run`, `path`, `script`, `check`, `setup`). When one
short word is not clear enough, use a longer phrase of short
words (`check_can_run`, `setup_work_folder`).

Prefer long, explicit function names when they describe the full
job. No abbreviations (`argument` not `arg`, `command` not
`cmd`). External tool names stay as-is (`llama-server`, `curl`,
`jq`, `head`, `sed`).

### Naming

- Variables use `UPPER_CASE` (settings, run state, and locals).
- Functions use `lower_case`.
- User-facing settings use the `SSA_` prefix. Internal run state
  does not.
- Top-level variable blocks (`# Users can set` and `# Internal`)
  keep names alphabetically ordered within each block. Do not
  alphabetize large string constants (prompts) with
  those lists.

Do not shadow top-level variables. Use `$1`, `$2`, or a different
local name inside helpers.

Prefer fewer variables. A value used in one place should be
written there. A function that only fills a variable for the
next line should print the value instead. Keep a variable when
the same fact is read again later (`CHUNK_START`,
`OUTPUT_START`).

### Settings and CLI

Every user-facing setting is an environment variable (`SSA_*`).
Document settings in `README.md`. Internal run state is not a
setting.

`ssa` and `ssa-local` have no flags. The words on the command
line are the task. Do not add flags to them.

### Error messages

When the user can fix a failure by changing a user-facing
setting, name the env var.

The programs point at the README:

```sh
die "SSA_MODEL not set; see README.md"
```

Keep hints one short clause after a semicolon. Prefer
`; see README.md` at the end of usage errors when useful.

Skip a "set ENV" hint when it would mislead:

- Internal harness failures (transcript I/O, log setup).
- Missing OS tools on `PATH` (`llama-server`, `curl`, `jq`, `head`,
  …). Name the tool and say it was not found on `PATH`.
- Failures outside the harness (missing model file, llama-server
  exits, `curl` fails).

The task has no env var. Say it was not found on the CLI.

The opening quote starts on the same line as `die`. Wrap at
80 columns with adjacent quoted parts.

### Status codes

A predicate used in `if name; then` returns 0 when the named
condition holds and 1 when it does not. Write the number at
the return. Keep predicates pure (no logging or side effects).

### Functions

- One clear job per function.
- Prefer `if` over `[ test ] && command` when branching among
  actions.
- Guard + `die`: `[ -n "$VAR" ] || die "…"`.
- Guard + `return`: `if [ -z "$VAR" ]; then return; fi`
  (or `return 1`, or `return $CONSTANT_NAME`) when that is
  the whole branch.
  Stay under 80 columns. A longer `then` stays a block.
- `case` arms prefer one line: `pattern) action ;;`.
  Indent each arm 4 spaces from `case`.

### Static strings

Long static text (prompts and errors) lives in top-level
variables, not inside functions. Give a long sed program a named local.
Split fixed text from substitution. Keep functions thin.

### Line length

Maximum 80 characters per line in `ssa` and `ssa-local` (code,
comments, static strings). Wrap with `\`, split quoted strings,
or multiple `printf`s. Do not shorten names just to fit.

### Quoting

Quote string literals in assignments and in `[ ]` / `=`
comparisons. Leave unquoted: numeric constants and status codes,
`case` patterns, signal names in `trap`.

### Streams

- stdout: action and loop output.
- `/dev/tty`: ask UI.
- stderr: harness errors only.

### File order

Follow the call graph:

1. Settings, run state, and static strings
2. `main()` first, then callees in call order
3. `main "$@"` on the last line

Each function sits below its last caller. Among callees of the
same caller, keep call order.

### Shell use

Do not add flags or env vars for behavior the caller's shell can
handle in one line at the call site.

| Need                    | Shell, not the agent              |
|-------------------------|-----------------------------------|
| Working directory       | `cd` before the program           |
| Environment             | `export VAR=value` or `VAR=value ssa …` |
| Diagnostic log file     | `ssa … 2>run.log`                 |
| Hung script / open pipe | wrap the program with `timeout`   |
| Repeated format errors  | Ctrl-C, `timeout`, or `ulimit -t` |
| Repeat for many tasks   | `for task in …; do …; done`       |

The same calls work with `ssa-local` in place of `ssa`. A run of
`ssa-local` whose stderr should be quiet takes `2>/dev/null`,
which hides llama-server's load messages.

A format error is sent back and the loop continues. Do not
add a count that stops `ssa-local`. `ssa` already stops at
`SSA_MAX_MODEL_PROMPTS`.

Ask: could the user do this with `cd`, `export`, or a redirect?
If yes, leave it out of the agent.
