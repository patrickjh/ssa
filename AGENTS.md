# AGENTS.md

Instructions for coding agents working in this repo. Humans: start with
[README.md](README.md). Settings and defaults: `./ssa -h`. Design details and
style rules are below; do not duplicate settings or behavior that `-h` and
`ssa` already define. Open work lives in `.plan/`. A new file under
`.plan/tasks/` is not added to `plan.txt`; only list a stem there when
that job should run next. `.plan/maybeNot/` is ideas that may not
belong in ssa; do not implement those unless a human moves the file
to `tasks/`.

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
│   ├── runTests.sh    # only entry point; parallel, per-test temp
│   ├── testUtils.sh   # functions only (sourced; no work on source)
│   ├── completeSimpleTask/
│   ├── editLargeFileByChunks/
│   ├── showHelp/
│   └── writeFileRequest/
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

- Needs `curl`, `jq`, and usual POSIX tools on `PATH` (`cat`, `grep`,
  `head`, `sed`, …). `ssa` checks these at startup (`head` is used to
  take the first action line of a model reply).
- ssa targets **POSIX systems only**. On Windows use WSL.
- Help: `./ssa -h` (or `sh ssa -h`).
- Smoke run (needs a real API): set `SSA_URL`, `SSA_KEY` if
  required, and `SSA_MODEL`; add `SSA_NO_ASK=1` when there is no TTY.
- Keep temp logs: `SSA_KEEP_TEMP=1`.
- Live tests: **only** via `sh tests/runTests.sh`. The runner starts
  each `*.test.sh` in a background process with its own temp folder
  and harness env (`TEST_TEMP_FOLDER`, `TEST_UTILS_FILE`), waits,
  then prints a ran/failed count and cleans up. Test files are
  top-to-bottom scripts that source `testUtils.sh` and call its
  functions; do not run `*.test.sh` alone.
- When adding agent-loop stories: fake `curl` on `PATH`, canned
  `replyN.txt` as chat-completions JSON, prefer `SSA_NO_ASK=1`; skip
  `sudo`/`doas` and real `/dev/tty` requirements so tests run on
  minimal POSIX setups.

## Boundaries

- Keep the product surface small: one executable (`ssa`) plus docs.
  Keep `ssa` under 1000 lines.
  Do not bring back `bin/` / `libexec/` / pluggable model runners.
- Edit `ssa` in place; keep **≤80 characters per line**.
- Do not invent flags or env vars for things the caller’s shell can do
  (`cd`, `export`, redirects).
- Keep `-h` short: `-h` / `--help`, environment, one loop paragraph,
  exit codes. Do not copy Design or README recipes into help. When
  behavior changes, update `ssa` and this file. Only add a help
  sentence if a setting’s meaning would otherwise be unclear.
- Ask before committing or pushing.
- New acceptance coverage goes under `tests/` (camelCase story folders,
  `folder.txt` explaining the folder, one case per explicitly named
  `*.test.sh`).

---

# Design

## Goal

Agent loop (prompt → treat reply as shell script → run → messages →
repeat) with:

- OpenAI-compatible HTTP via **curl** and **jq** (built in)
- **Ask-user** approval (on by default)
- **Sandbox command** for the model script (default `sh`; override for
  containers / pledge / jails, etc.)

## Program flow

1. **Start** — Parse `-h` and the task, validate settings and tools (`curl`,
   `jq`, `head`, …), create temp folder, write system prompt and task
   into `messages.json` (if `SSA_CONTEXT` is set, that file is appended
   to the first user turn after `Context:`), create `prompt0/`, seed
   with a bootstrap `echo starting the agent` (ask-user applies when
   enabled).
2. **Loop** — For each model prompt (`prompt1+`), cap `messages.json`
   to `MAX_MESSAGES_BYTES` (keep the system prompt, the first user
   turn, and the newest turns; die if one turn is still over the cap),
   copy it to `promptN/messages.json` (temp log only), run `call_curl`
   against `messages.json` (system / user / assistant roles); treat
   the reply as the script. If done marker, stop; if write request
   (first action line `# write file: PATH`, after leading blank lines
   and `#` notes), write everything after that line to PATH through
   the ask / command layers; if edit request (first action line
   `# edit file: PATH`), apply one unique SEARCH/REPLACE in the
   harness then write through the same layers; if the reply is empty,
   has a markdown fence line, has thinking tags (`<think>` or
   `<|channel>thought`), or `sh -n` fails, append a format error
   and continue (do not run it); else run through ask / command
   layers; capture script output, then append it to `messages.json`
   (if jq cannot hold it, or it contains a NUL, omit those bytes and
   append a short note plus the exit code instead).
3. **Stop** — Exit `0` when the first action line is `# complete`
   (leading blank lines and `#` notes skipped; trailing newlines
   ignored: `[ "$(first_action_line)" = '# complete' ]`).
   `first_action_line` keeps `# complete`, `# write file:…`,
   `# edit file:…`, or a non-`#` line (`grep -E`), takes the first
   (`head -n 1`), and fails if none remain (`grep .`). Exit `1` on
   harness failure or max model prompts. SIGHUP / SIGINT /
   SIGTERM → `129` / `130` / `143`.
4. **Review** — After the loop (done or hit max), append a user turn
   asking what would have made this run go better, POST once more (not
   counted in `SSA_MAX_MODEL_PROMPTS` or the status prompt count),
   print the reply on stderr through `sanitize_output`, and do not
   run it. Skip on die / HUP / INT / TERM. A failed review curl is fatal.

## Environment

Harness state is **not** exported into child processes (`sh` or
`SSA_SANDBOX_COMMAND`).

Private (not exported): `PID`, `PROMPT_COUNTER`, `TEMP_FOLDER`.
Startup unsets those names so an inherited export is dropped.
Pipeline subshells inside the harness still see them; model scripts and
custom sandbox commands do not inherit them.

`PID` holds the agent PID at startup for `die` (SIGUSR1). It must
not be replaced with `$$` inside a pipeline subshell.

User-facing settings (`SSA_MODEL`, `SSA_NO_ASK`, …) are environment
knobs; see Settings below and `ssa -h`.

## Sandboxing (two layers)

Ask is optional. The sandbox command always runs (default `sh`).
Combine both.

### 1. Ask user — off when `SSA_NO_ASK=1` (default `0`)

- `SSA_NO_ASK=0|1` (`1` skips ask).
- When `0`: show each **model** script on **stderr**; print the
  `[Y]es / [N]o / [Q]uit` prompt on stderr; read the answer from
  `/dev/tty`.
- Yes → run the script (other layers). No → rejection text on stdout,
  status `1` (loop continues); then `reason:` on stderr and one line
  from `/dev/tty` (empty skips). A typed reason is logged to
  `promptN/userFeedback.txt` and appended as `Reason: …` on the user
  turn, not on stdout. Quit → `die`. Fake-curl `SSA_NO_ASK=1` stories
  cannot cover this tty read.
- Ask listing and other harness UI of untrusted bytes show CR as
  `\r`, ESC as `\e`, and other non-print (except tab) as `?`. The
  file fed to the sandbox and live script stdout are unchanged.
- Invalid answers print `invalid input: …` on stderr and re-prompt.
- Answers are logged to `promptN/userAnswer.txt` when ask runs.
- Requires an openable `/dev/tty` when ask is enabled. Read failure
  from `/dev/tty` is fatal. Batch jobs: `SSA_NO_ASK=1`.

### 2. Sandbox command — `SSA_SANDBOX_COMMAND` (default `sh`)

- Validated with `command -v` at startup. Default `sh`.
- The harness feeds that command’s **stdin** from
  `latestModelResponse.txt` (scripts and writes) or from edited
  bytes (successful edits).
- Contract: stdout/stderr from the run; exit code recorded in
  `messages.json`. Unrecoverable stop from inside the harness uses `die`
  (SIGUSR1 to `PID`). Custom sandbox commands do not get `PID`
  in their environment. Write turns need sh-style `-c` and `sed`.
  Edit turns need sh-style `-c` and `cat` (jq runs in the harness).
- Hung scripts are not killed by ssa. Point `SSA_SANDBOX_COMMAND` at a
  wrapper that runs `timeout` or `timelimit` around `sh`, passing
  `"$@"` through so write/edit `-c` still works. `COMMAND` is one
  executable (`command -v`), not `timeout 60 sh`. Use a process
  group (`timeout --foreground`, or `setsid`): a background child
  that inherits the pipe keeps `tee` waiting after the parent exits.

### How the script is run

After ask (or after ask is disabled):

`"$SSA_SANDBOX_COMMAND" < stdin`

Write and edit turns add sh-style `-c` and the target path as `$0`.

## Write requests (`# write file:`)

A reply whose **first action line** is `# write file: PATH` (path
runs to end of line, must be non-empty) is a file write request, not a
script. Leading blank lines and `#` notes are skipped;
`first_action_line` returns that line. Everything after the sentinel
is the raw file contents — no heredocs, no quoting, no escaping.
Detection is in `reply_is_write_request`; done-marker and blank-reply
checks come first; `sh -n` is not applied to write requests.

- The write runs through the same ask / sandbox layers as a script.
  The sandbox command is invoked with `-c`,
  `sed -n "/^# write file: ./,$p" | sed 1d > "$0"` then
  `printf "wrote file: %s\n" "$0"`, and PATH (`$0` in the `-c`
  script), with the full `latestModelResponse.txt` on **stdin**.
  The first sed keeps from the sentinel to the end; `sed 1d` drops
  the sentinel. That works when the sentinel is line 1 (unlike
  `1,/pattern/d`). The path is a positional argument — never
  interpolated into script text — so no quoting problem exists.
  Sandbox commands must support sh-style `-c` for write turns.
- Success prints `wrote file: PATH`; failures (missing parent folder,
  permissions) land in `messages.json` like any script failure. The
  harness does **not** create parent folders; the model sends a
  normal `mkdir` script turn first.
- One file per reply. `save_model_reply_to_file` writes the model
  string with `jq -j` (raw, no extra newline) straight onto
  `latestModelResponse.txt`, so trailing blank lines in the payload
  are kept. `jq -b` is added when the probe at startup succeeds, so
  jq builds that would otherwise write CRLF do not.

This is harness-parsed (unlike the earlier prompt-only raw-tail idea)
because relying on POSIX stdin sharing proved non-portable across
shells used as the sandbox command.

## Edit requests (`# edit file:`)

A reply whose **first action line** is `# edit file: PATH` (path
runs to end of line, must be non-empty) is a unique search-and-replace,
not a script. Leading blank lines and `#` notes are skipped;
`first_action_line` returns that line. Everything after the sentinel
is one SEARCH/REPLACE pair:

```
<<<<<<< SEARCH
old bytes, copied exactly
=======
new bytes
>>>>>>> REPLACE
```

Detection is in `reply_is_edit_request`; done-marker, blank-reply, and
write-request checks come first; `sh -n` and fence/think checks are
not applied (the payload may contain those bytes).

- The harness extracts the payload (from the sentinel, minus that
  line) and runs `jq` `split` so the old string matches **exactly
  once**. Failed edits print `edit failed: PATH: …` on stdout
  (file not found, missing markers, empty old string, matched 0 or
  2+ times) with exit `1` and do not change the file. Same recovery
  as a failed write.
- On success the sandbox command is invoked with `-c`,
  `cat > "$0" && printf "edited file: %s\n" "$0"`, PATH as `$0`,
  and the new file bytes on **stdin**. The path is a positional
  argument — never interpolated into script text. Sandbox commands
  must support sh-style `-c` for edit turns; they do not need `jq`.
- One file, one replace per reply. Empty new string deletes the
  old block. Marker lines in old/new are ambiguous; fail closed.

## Model (curl)

Built-in OpenAI-compatible `/chat/completions` client:

- Required: `SSA_URL` (URL curl POSTs the chat-completions body
  to), `SSA_MODEL`
- Optional: `SSA_KEY`, `SSA_REQUEST_JSON` (JSON object merged
  into the request body; model and messages from ssa win on key
  conflicts)
- Extra curl flags: put a `curl` wrapper earlier on `PATH` (ssa has no
  `--curl-args`). curl also honors `https_proxy` and related env vars.
- At setup, if `SSA_KEY` is set, write
  `$TEMP_FOLDER/authHeader.txt` for curl `-H @file`, then
  `unset SSA_KEY` so model scripts do not inherit the key and
  curl argv does not contain it. `authHeader.txt` is overwritten and
  removed on every exit (including `SSA_KEEP_TEMP=1`).
- Once per run, writes `SSA_URL` to `$TEMP_FOLDER/url.txt`
  and the task to `$TEMP_FOLDER/task.txt` (log only). If `SSA_CONTEXT`
  is set, a copy of that file is `$TEMP_FOLDER/context.txt`.
- Temp working files include `authHeader.txt` while the run needs it
  (always deleted on exit), `messages.json`, `latestModelResponse.txt`,
  `latestScriptExitCode.txt`, and `latestScriptOutput.txt` (tee’d
  script output before the user-turn append to `messages.json`).
  Output that `jq --rawfile` cannot hold, or that contains a NUL, is
  omitted from that user turn; stdout is unchanged.
- Before each **model** prompt (`prompt1+`), the harness caps
  `messages.json` to `MAX_MESSAGES_BYTES` (system prompt, first user
  turn, and newest turns; die if one remaining turn is still over the cap),
  then copies it to `$TEMP_FOLDER/promptN/messages.json` for
  debugging (`SSA_KEEP_TEMP=1`). `prompt0/` is created for the fake-first
  bootstrap (no curl / no messages copy). `N` matches
  `PROMPT_COUNTER`.
- Per-prompt HTTP logs live under `promptN/` for model prompts:
  `body.json`, `requestExtra.json`, and `response.txt`
- `call_curl` / jq read `messages.json` (not one concatenated user
  blob); no stdin prompt spool
- Model replies are extracted with `jq -j` (and `jq -b` when that flag
  works; probed once at startup) onto `latestModelResponse.txt`
- Request body is `system` / `user` / `assistant` messages plus
  `SSA_REQUEST_JSON` merged in. After the agent loop, one more POST
  asks for plain-text feedback (not a script). Curl uses `--fail`,
  `--retry`, `--retry-connrefused`, `--retry-max-time` 120,
  `--connect-timeout` 30, and `--max-time` 900. A failed curl is
  fatal.

## Settings summary

| Setting | Default |
|---------|---------|
| `SSA_CONTEXT` | empty (off) |
| `SSA_KEEP_TEMP` | `0` (discard) |
| `SSA_KEY` | empty (optional) |
| `SSA_MAX_MODEL_PROMPTS` | `20` |
| `SSA_MODEL` | unset (required) |
| `SSA_NO_ASK` | `0` (ask) |
| `SSA_REQUEST_JSON` | empty |
| `SSA_SANDBOX_COMMAND` | `sh` |
| `SSA_URL` | unset (required) |

Settings are environment only. The only flags are `-h` / `--help`.
Unknown `-*` is a bad option, not a task word. Per-run overrides:
`VAR=value ssa …`.

**Streams:** script output and help on **stdout**; ask UI (script listing,
prompts, invalid-input lines), review feedback, harness errors, and the
final status line on **stderr**.

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
prompts; exit `129` / `130` / `143` on SIGHUP / SIGINT / SIGTERM (no
status line; temp cleanup unless `SSA_KEEP_TEMP=1`).

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
- **User-facing settings** use the `SSA_` prefix. Internal run
  state does not.
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
`messages.json`). Shell variables that hold paths use `UPPER_CASE`
with `_FILE` / `_FOLDER` / `_SCRIPT`.

**Do not shadow top-level variables.** Use `$1`, `$2`, or different local
names inside helpers.

## Settings and CLI

Every **user-facing setting** is an environment variable (`SSA_*`).
The only flags are `-h` / `--help`. Unknown `-*` is a bad
option, not a task word. Document settings in `-h`. Short forms are
rare (`-h` only). Internal run state is not a setting.

## Error messages

When the user can fix a failure by changing a **user-facing setting**,
say how: name the env var. Pattern:

```sh
die "SSA_URL not set; set SSA_URL; see ssa -h for help"
```

Keep hints one short clause after a semicolon. Prefer
`; see ssa -h for help` at the end of usage errors when useful.

**Skip “set ENV” hints** when that would mislead:

- Internal harness failures (messages I/O, temp folder setup).
- Missing OS tools on `PATH` (`curl`, `jq`, `head`, …) —
  say to install or put the tool on `PATH`.
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
| Keep temp logs | `SSA_KEEP_TEMP=1` |
| Extra curl flags | `curl` wrapper earlier on `PATH` |
| Hung script / open pipe | `SSA_SANDBOX_COMMAND` wrapping `timeout` |
| HTTP(S) proxy | `https_proxy` / `http_proxy` (curl) |
| Repeat for many tasks | `for task in …; do …; done` |

Ask: *could the user do this with `cd`, `export`, or a redirect?* If yes,
leave it out of the agent.
