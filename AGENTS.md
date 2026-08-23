# AGENTS.md

Instructions for coding agents working in this repo. Humans: start with
[README.md](README.md). Flags and defaults: `./ssa -h`. Design details and
style rules are below; do not duplicate settings or behavior that `-h` and
`ssa` already define.

## Overview

`ssa` is a Simple Shell Agent in one POSIX `sh` file: prompt a model for
shell scripts, run them, feed output back, repeat until done.

Inspired by [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent):
only shell as the tool, each action in a fresh process, a simple loop.

## Layout

```
ssa/
├── AGENTS.md          # this file (agent instructions)
├── LICENSE
├── README.md          # human intro and try-it
├── ssa                # the only source file — edit this
├── tests/             # live stories + acceptance tests
│   ├── runTests.sh    # only entry point; per-test temp + trap
│   ├── testUtils.sh   # functions only (sourced; no work on source)
│   ├── showHelp/
│   ├── writeFileRequest/
│   └── editLargeFileByChunks/
└── oldTests/          # archived suites; not current
```

Prefer **camelCase** for story folder names under `tests/`
(e.g. `showHelp`, `completeSimpleTask`).

**One test case per `*.test.sh` file.** Name the file so it reads clearly
when browsing the folder — longer, explicit names are good
(e.g. `showHelpWithDashH.test.sh`, not `help1.test.sh`).

**Test files live exactly one level deep**:
`tests/<storyFolder>/<caseName>.test.sh`. The runner discovers only that
pattern (`tests/*/*.test.sh`); files at other depths are silently
skipped.

`testUtils.sh` must **only define functions**. Sourcing it must not run
checks, resolve paths, or set up state — callers invoke helpers such as
`run_ssa` / `expect_*`, which do runtime checks when needed.

## Setup and commands

- Needs `curl` and `jq` on `PATH`.
- ssa targets **POSIX systems only**. On Windows use WSL.
- Help: `./ssa -h` (or `sh ssa -h`).
- Smoke run (needs a real API): set `OPENAI_URL`, `OPENAI_API_KEY` if
  required, and `-m` / `SSA_MODEL`; add `--no-ask` when there is no TTY.
- Keep temp logs: `--keep-temp` or `SSA_KEEP_TEMP=1`.
- Live tests: **only** via `sh tests/runTests.sh`. The runner creates a
  per-test temp folder, exports harness env (`TEST_TEMP_FOLDER`,
  `TEST_UTILS_FILE`), traps cleanup, then runs each `*.test.sh` as its
  own process. Test files are top-to-bottom scripts that source
  `testUtils.sh` and call its functions; do not run `*.test.sh` alone.
- `oldTests/` is archive only. When adding agent-loop stories: fake `curl`
  on `PATH`, canned `replyN.txt` as chat-completions JSON, prefer
  `--no-ask`; skip `sudo`/`doas` and real `/dev/tty` requirements so
  tests run on minimal POSIX setups.

## Boundaries

- Keep the product surface small: one executable (`ssa`) plus docs.
  Do not bring back `bin/` / `libexec/` / pluggable model runners.
- Edit `ssa` in place; keep **≤80 characters per line**.
- Do not invent flags or env vars for things the caller’s shell can do
  (`cd`, `export`, redirects).
- Ask before committing or pushing.
- Leave `oldTests/` alone unless the task is to remake or remove tests.
- New acceptance coverage goes under `tests/` (camelCase story folders,
  `folder.txt` explaining the folder, one case per explicitly named
  `*.test.sh`).

---

# Design

## Goal

Agent loop (prompt → treat reply as shell script → run → transcript →
repeat) with:

- OpenAI-compatible HTTP via **curl** and **jq** (built in)
- **Ask-user** approval (on by default)
- Optional **Unix sandbox user**
- **Sandbox command** for the model script (default `sh`; override for
  containers / pledge / jails, etc.)

## Program flow

1. **Start** — Parse CLI and task, validate settings and tools (`curl`,
   `jq`, …), create temp folder, write system prompt and task into the
   transcript, create `prompt0/`, seed with a bootstrap
   `echo starting the agent` (ask-user applies when enabled).
2. **Loop** — For each model prompt (`prompt1+`), copy
   `fullTranscript.txt` to `promptN/transcript.txt` (temp log only), run
   `call_curl` against the live transcript; treat the reply as the
   script; if done marker, stop; if write request (first line
   `# write file: PATH`), write the rest of the reply to PATH through
   the ask / user / command layers; else run through ask / user /
   command layers; capture script output, then append it to the
   transcript. Empty replies run like any other script (usually a
   no-op) and get the normal script-result turn in the transcript.
3. **Stop** — Exit `0` when the model reply is `# task complete`
   (trailing newlines ignored: the check is
   `[ "$(cat latestModelResponse.txt)" = '# task complete' ]`).
   Exit `1` on harness failure or max model prompts.
   SIGINT / SIGTERM → `130` / `143`.

## Environment

Harness state is **not** exported into child processes (`sh`,
`--sandbox-command`, or `sudo`/`doas` children).

Private (not exported): `PID`, `PROMPT_COUNTER`, `TEMP_FOLDER`.
Pipeline subshells inside the harness still see them; model scripts and
custom sandbox commands do not inherit them unless the caller sets them.

`PID` holds the agent PID at startup for `die` (SIGUSR1). It must
not be replaced with `$$` inside a pipeline subshell.

User-facing settings (`SSA_MODEL`, `SSA_NO_ASK`, …) are normal env/CLI
knobs; see Settings below and `ssa -h`.

## Sandboxing (three layers)

Ask and sandbox user are optional. The sandbox command always runs
(default `sh`). Combine any of the three.

### 1. Ask user — off when `SSA_NO_ASK=1` (default `0`)

- CLI: `--no-ask` sets `1`. Env: `SSA_NO_ASK=0|1`.
- When `0`: show each **model** script on **stderr**; print the
  `[Y]es / [N]o / [Q]uit` prompt on stderr; read the answer from
  `/dev/tty`.
- Yes → run the script (other layers). No → rejection text on stdout,
  status `1` (loop continues). Quit → `die`.
- Ask listing shows CR as `\r`, ESC as `\e`, and other non-print
  bytes (except tab) as `?`. The file fed to the sandbox is unchanged.
- Invalid answers print `invalid input: …` on stderr and re-prompt.
- Answers are logged to `promptN/userAnswer.txt` when ask runs.
- Requires an openable `/dev/tty` when ask is enabled. Read failure
  from `/dev/tty` is fatal. Batch jobs: `--no-ask` or `SSA_NO_ASK=1`.

### 2. Sandbox user — `SSA_SANDBOX_USER` (default empty)

- CLI: `--sandbox-user USER` (login **name or numeric UID**).
- When set: validate with `id` (exists, not root, not the current UID),
  require `sudo` or `doas`, then run the sandbox command as that user.

### 3. Sandbox command — `SSA_SANDBOX_COMMAND` (default `sh`)

- CLI: `--sandbox-command COMMAND`, or leave default `sh`.
- Validated with `command -v` at startup.
- The harness feeds `latestModelResponse.txt` on that command’s **stdin**.
- Contract: stdout/stderr from the run; exit code recorded in the
  transcript. Unrecoverable stop from inside the harness uses `die`
  (SIGUSR1 to `PID`). Custom sandbox commands do not get `PID`
  in their environment.

### How the script is run

After ask (or after ask is disabled), `latestModelResponse.txt` is fed to:

| `SSA_SANDBOX_USER` | Runs |
|--------------------|------|
| unset | `"$SSA_SANDBOX_COMMAND" < latestModelResponse.txt` |
| set | `sudo`/`doas -u USER -- "$SSA_SANDBOX_COMMAND"` with that file on stdin |

User set → **change user, then run the sandbox command**.

## Write requests (`# write file:`)

A reply whose **first line** is exactly `# write file: PATH` (path
runs to end of line, must be non-empty) is a file write request, not a
script. Everything after the first line is the raw file contents — no
heredocs, no quoting, no escaping. Detection is in
`reply_is_write_request`; done-marker check comes first.

- The write runs through the same ask / sandbox layers as a script.
  The sandbox command is invoked with `-c`,
  `sed 1d > "$0" && printf "wrote file: %s\n" "$0"`, and PATH
  (`$0` in the `-c` script), with the full `latestModelResponse.txt`
  on **stdin**. `sed 1d` drops the sentinel line; the rest is the
  payload. The fd is opened by the harness, so sandbox user
  permissions on the temp folder do not matter. The path is a
  positional argument — never interpolated into script text — so no
  quoting problem exists. Sandbox commands must support sh-style
  `-c` for write turns.
- Success prints `wrote file: PATH`; failures (missing parent folder,
  permissions) land in the transcript like any script failure. The
  harness does **not** create parent folders; the model sends a
  normal `mkdir` script turn first.
- One file per reply. `save_model_reply_to_file` writes the model
  string with `jq -j` (raw, no extra newline) straight onto
  `latestModelResponse.txt`, so trailing blank lines in the payload
  are kept. `jq -b` is added when the probe at startup succeeds, so
  jq builds that would otherwise write CRLF do not.
- Large-file edits (prompt-taught **contract**, no prescribed
  program): split into a chunk folder any way such that `cat chunks/*`
  reproduces the file, prove it with
  `cat chunks/* > check && cmp FILE check` **before** editing,
  overwrite one chunk per reply with a write request, join with
  `cat chunks/* > FILE.new && mv`.

This is harness-parsed (unlike the earlier prompt-only raw-tail idea)
because relying on POSIX stdin sharing proved non-portable across
shells used as the sandbox command.

## Model (curl)

Built-in OpenAI-compatible `/chat/completions` client:

- Required: `OPENAI_URL` (full `http(s)://…/chat/completions`), `-m` /
  `SSA_MODEL`
- Optional: `OPENAI_API_KEY`, `SSA_MAX_HTTP_REQUESTS` (default 5)
- Extra curl flags: put a `curl` wrapper earlier on `PATH` (ssa has no
  `--curl-args`). curl also honors `https_proxy` and related env vars.
- At setup, if `OPENAI_API_KEY` is set, write
  `$TEMP_FOLDER/authHeader.txt` for curl `-H @file`, then
  `unset OPENAI_API_KEY` so model scripts do not inherit the key and
  curl argv does not contain it. `authHeader.txt` is overwritten and
  removed on every exit (including `--keep-temp`).
- Once per run, writes `OPENAI_URL` to `$TEMP_FOLDER/openaiUrl.txt`
  and the task to `$TEMP_FOLDER/task.txt` (log only; transcript seed
  still uses `TASK`)
- Temp working files include `authHeader.txt` while the run needs it
  (always deleted on exit), `latestModelResponse.txt`,
  `latestScriptExitCode.txt`, and `latestScriptOutput.txt` (tee’d
  script output before transcript append).
- Before each **model** prompt (`prompt1+`), the harness copies
  `fullTranscript.txt` to `$TEMP_FOLDER/promptN/transcript.txt` for
  debugging (`--keep-temp`). `prompt0/` is created for the fake-first
  bootstrap (no curl / no transcript copy). `N` matches
  `PROMPT_COUNTER`.
- Per-prompt HTTP logs live under `promptN/` for model prompts:
  `body.json`, and `curlA/` with `headers.txt`, `response.txt`,
  `httpCode.txt`, `exit.txt`
- `call_curl` / jq read the live transcript (`jq --rawfile`); no stdin
  prompt spool
- Model replies are extracted with `jq -j` (and `jq -b` when that flag
  works; probed once at startup) onto `latestModelResponse.txt`
- Sent as one `user` message; retries on transient HTTP errors;
  insufficient-quota `429` is fatal

Non-zero curl exit → retry the loop (next call number gets a fresh
`promptN/transcript.txt` log snapshot).

## Settings summary

| Setting | CLI | Default |
|---------|-----|---------|
| `OPENAI_API_KEY` | `--openai-api-key` | empty (optional) |
| `OPENAI_URL` | `--openai-url` | unset (required) |
| `SSA_KEEP_TEMP` | `--keep-temp` | `0` |
| `SSA_MAX_HTTP_REQUESTS` | `--max-http-requests` | `5` |
| `SSA_MAX_MODEL_PROMPTS` | `--max-model-prompts` | `20` |
| `SSA_MODEL` | `-m` / `--model` | unset (required) |
| `SSA_NO_ASK` | `--no-ask` → `1` | `0` |
| `SSA_SANDBOX_COMMAND` | `--sandbox-command` | `sh` |
| `SSA_SANDBOX_USER` | `--sandbox-user` | empty |

CLI overrides env when both are set.

**Streams:** script output and help on **stdout**; ask UI (script listing,
prompts, invalid-input lines), harness errors, and the final status line on
**stderr**.

---

# Style

Conventions for editing `ssa`. **Style rules only.** Wiring, settings,
names, status codes, and behavior live in `ssa` and `-h`.

## Unix conventions

`ssa` is a Unix-style CLI. When a rule here conflicts with a
**well-established Unix or GNU convention**, follow the Unix convention
unless this file documents a deliberate exception.

Examples: requested help (`-h`, `--help`) on **stdout**; interleaved
script output live on **stdout**; `die` messages and the final status on
**stderr**; exit `0` on success; exit `1` on harness failure or max model
prompts; exit `130` / `143` on SIGINT / SIGTERM (no status line; temp
cleanup unless `--keep-temp`).

## Simple words

**Readability comes first.** Favor plain words of one or two syllables
(`run`, `path`, `script`, `check`, `setup`). When one short word is not
clear enough, use a longer phrase of short words (`check_can_run`,
`setup_work_folder`).

**Prefer long, explicit function names** when they describe the full job.
**No abbreviations** (`argument` not `arg`, `command` not `cmd`). External
tool names stay as-is (`curl`, `jq`, `-f`, etc.).

## Naming

- **Variables** use `UPPER_CASE` (settings, run state, and locals).
- **Functions** use `lower_case`.
- **User-facing settings** use the `SSA_` prefix (except OpenAI’s
  `OPENAI_*`). Internal run state does not.
- **Top-level variable blocks** (`# Users can set` and `# Internal`) keep
  names **alphabetically ordered** within each block. Do not alphabetize
  large string constants (help text, prompts) with those lists.

Path suffix by what the variable holds:

| Suffix | Holds |
|--------|--------|
| `_FILE` | A file |
| `_FOLDER` | A folder |
| `_SCRIPT` | Path to an executable file |

On-disk names under the temp folder use **camelCase** (e.g.
`fullTranscript.txt`). Shell variables that hold paths use `UPPER_CASE`
with `_FILE` / `_FOLDER` / `_SCRIPT`.

**Do not shadow top-level variables.** Use `$1`, `$2`, or different local
names inside helpers.

## Settings and CLI

Every **user-facing setting** has **both** an environment variable and a
long-form CLI flag. The flag overrides the env var when set on the
command line. Document each pair in `-h`. Short forms are rare (`-h`,
`-m` only). Internal run state is not a setting.

## Error messages

When the user can fix a failure by changing a **user-facing setting**,
say how: the CLI flag and the matching env var. Pattern:

```sh
die "OPENAI_URL not set; use --openai-url or OPENAI_URL with a full " \
    "http(s)://…/chat/completions URL; see ssa -h for help"
```

Keep hints one short clause after a semicolon. Prefer
`; see ssa -h for help` at the end of usage errors when useful.

**Skip “use --flag or ENV” hints** when that would mislead:

- Internal harness failures (transcript I/O, temp folder setup).
- Missing OS tools on `PATH` (`curl`, `jq`, `sudo`/`doas`, …) — say to
  install or put the tool on `PATH`.
- Failures fixed outside ssa (API billing, account quota).

The task has **no env var** — say to pass words after options or pipe
stdin.

`die` prints on stderr and sends SIGUSR1 to `PID`. Opening quote
starts on the **same line** as `die`. Wrap at **80 columns** with
adjacent quoted parts.

## Status codes

Control-flow numbers used for `return` and loop status are **named
constants** at the top of the script — not magic numbers in function
bodies. Predicates used in `if name; then` return **0 when the named
condition holds** (`IS_TRUE` / `IS_FALSE`). Keep predicates pure (no
logging or side effects). Use `return $CONSTANT_NAME` (with `$`).

## Functions

- One clear job per function.
- Prefer `if` over `[ test ] && command` when branching among actions.
- Guard + `die`: `[ -n "$VAR" ] || die "…"`.
- `case` arms prefer one line: `pattern) action ;;`.

## Static strings

Long static text (prompts, help, errors) lives in **top-level
variables**, not inside functions. Give **sed** programs a named local.
Split fixed text from substitution; keep functions thin.

## Line length

**Maximum 80 characters per line** in `ssa` (code, comments, static
strings). Wrap with `\`, split quoted strings, or multiple `printf`s.
Do not shorten names just to fit.

## Quoting

Quote string literals in assignments and in `[ ]` / `=` comparisons.
Leave unquoted: numeric constants and status codes, `case` patterns,
signal names in `trap`.

## Streams

- **stdout** — interleaved script output and requested help.
- **stderr** — ask UI, harness errors, final status line.

## File order

Follow the call graph:

1. Settings, run state, and static strings
2. `main()` first, then callees in **call order**
3. `main "$@"` on the last line

Each function sits **below its last caller**. Among callees of the same
caller, keep call order.

## Shell use

Do not add flags or env vars for behavior the caller’s shell can handle
in one line at the call site.

| Need | Shell, not agent |
|------|------------------|
| Working directory | `cd` before `ssa` |
| Environment | `export VAR=value` or `VAR=value ssa …` |
| Diagnostic log file | `ssa … 2>run.log` |
| Keep temp logs | `--keep-temp` or `SSA_KEEP_TEMP=1` |
| Extra curl flags | `curl` wrapper earlier on `PATH` |
| HTTP(S) proxy | `https_proxy` / `http_proxy` (curl) |
| Repeat for many tasks | `for task in …; do …; done` |

Ask: *could the user do this with `cd`, `export`, or a redirect?* If yes,
leave it out of the agent.
