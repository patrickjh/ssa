# AGENTS.md

Instructions for coding agents in this repo. Behavior is
in `ssa`. This file is how to work, what stays out, and
the style rules for the shell program.

## This stage

Open work is plan.txt. Change this file in place when a
decision about editing, style, or scope changes. Behavior
changes go in `ssa`. Cite no line numbers.

## Layout

One executable, `ssa`, POSIX `sh`, at or under 1000 lines,
80 columns. Edit `ssa` in place.

```
ssa
├── AGENTS.md
├── README.md           # help, outside the program
├── plan.txt            # open work
└── ssa                 # the only source file
```

`README.md` is the help. Keep it short: how to run,
environment, one loop paragraph, exit codes. Do not copy
`ssa` into `README.md` beyond what a person needs to run
the program. Update `README.md` when a setting's meaning
would otherwise be unclear.

## Boundaries

Keep the product surface small: one executable. Help is
`README.md`, outside the program. This repo has no tests.
Do not add `bin/` or `libexec/`. Do not invent flags or env vars
for things the caller's shell can do (`cd`, `export`, redirects).

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
better ways to use ssa. Keep every record that review needs.

Another goal is low token use. Some devices generate
tokens slowly, and a run should stay usable there. Keep
prompts and replies short, and do not add a turn or a
thinking trace the device must generate.

Another goal is a run with no network at all. The model,
the files, and the log stay on the machine. A run should
finish the same way with the network off.

Another goal is a computer that stays responsive while a
run is going. The model load and the reply can be slow.
They should not lock the machine. Leave memory and CPU
for the rest of the system, even when that slows
llama-cli.

Another goal is llama-cli options that work when the
model weights are bigger than memory. The weights stream
off a drive. A run should keep going in that case.

## Kept out

JSON tool calls. A tools array on the request. A second
edit shape (unified diff). Fence unwrapping. A chunk-file
compare protocol. Thinking left on, with the trace stripped
from history. The end-of-run review generation. Splitting
the file into lib or bin. A native Windows harness. An HTTP
client for a model server.
A fresh llama-cli process on every turn.
Capping action output. Script output is appended in full.
A long command can fill the context.

## Style

Style rules only. Behavior is in `ssa`. `README.md` is the
short help.

### Unix conventions

`ssa` is a Unix-style CLI. When a rule here conflicts with a
well-established Unix or GNU convention, follow the Unix
convention unless this file documents a deliberate exception.

### Simple words

Readability comes first. Favor plain words of one or two
syllables (`run`, `path`, `script`, `check`, `setup`). When one
short word is not clear enough, use a longer phrase of short
words (`check_can_run`, `setup_work_folder`).

Prefer long, explicit function names when they describe the full
job. No abbreviations (`argument` not `arg`, `command` not
`cmd`). External tool names stay as-is (`llama-cli`, `head`,
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

Do not shadow top-level variables. Use `$1`, `$2`, or a different
local name inside helpers.

Prefer fewer variables. A value used in one place should be
written there. A function that only fills a variable for the
next line should print the value instead. Keep a variable when
the same fact is read again later (`CHUNK_START`,
`OUTPUT_START`).

### Settings and CLI

Every user-facing setting is an environment variable (`SSA_*`).
The program has no flags. The words on the command line are
the task. Document settings in `README.md`.
Internal run state is not a setting.

### Error messages

When the user can fix a failure by changing a user-facing
setting, name the env var. Pattern:

```sh
die "SSA_LOG_FOLDER is not a directory; see README.md"
```

Keep hints one short clause after a semicolon. Prefer
`; see README.md` at the end of usage errors when useful.

Skip a "set ENV" hint when it would mislead:

- Internal harness failures (transcript I/O, temp folder setup).
- Missing OS tools on `PATH` (`llama-cli`, `head`, …). Say to
  install the tool or put it on `PATH`.
- Failures outside the harness (missing model file, `llama-cli`
  exits).

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

Maximum 80 characters per line in `ssa` (code, comments, static
strings). Wrap with `\`, split quoted strings, or multiple
`printf`s. Do not shorten names just to fit.

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
| Working directory       | `cd` before `ssa`                 |
| Environment             | `export VAR=value` or `VAR=value ssa …` |
| Diagnostic log file     | `ssa … 2>run.log`                 |
| Hung script / open pipe | wrap `ssa` with `timeout`         |
| Repeat for many tasks   | `for task in …; do …; done`       |

Ask: could the user do this with `cd`, `export`, or a redirect?
If yes, leave it out of the agent.
