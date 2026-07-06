# Shell coding style

Conventions for `ssa`. Project rules: [DESIGN.md](DESIGN.md#project-rules). How it works: [DESIGN.md](DESIGN.md).

**Style rules only.** Wiring, settings, names, status codes, and behavior live in `libexec/ssa/ssa.sh` (and `-h`). Do not duplicate them here.

## Unix conventions

`ssa` is a Unix-style CLI. When a rule in this file conflicts with a **well-established Unix or GNU convention**, follow the **Unix convention** unless [DESIGN.md](DESIGN.md) documents a deliberate exception.

Examples: requested help (`-h`, `--help`) on **stdout**; interleaved script output live on **stdout** during each run; `util_die` messages, helper errors, and final status on **stderr**; exit `0` on success; exit `1` on harness or usage failure (`util_die`) or max model calls. Exit `130` or `143` when `ssa` receives SIGINT / SIGTERM (no status line; session cleanup unless `--keep-session`).

## Simple words

**Readability comes first.** Names should be easy to read at a glance — even if that means a longer phrase.

Favor plain words of **one or two syllables** (`run`, `path`, `script`, `check`, `setup`). Pick `run` over `execute`, `path` over `directory`. When one short word is not clear enough, use a **longer phrase of short words** (`check_can_run`, `setup_work_folder`) instead of one fancy or clipped word.

Longer phrases are fine when they make intent obvious. Do not shorten a name just to save characters if clarity suffers.

**Prefer long, explicit function names** when they describe the full job (`call_model_then_run_script`, not `run_step`). Short abstract names are for simple helpers only (`invoke_model_runner`, `util_die`).

**No abbreviations.** Use full words only: `argument` not `arg`, `command` not `cmd`, `directory` not `dir`. If a short full word does not exist, use a short phrase of full words instead of clipping.

**Exception:** names from external tools stay as-is (`llama-completion`, `-f`, etc.).

## Naming

Names should be **clear and readable**: full words, favoring 1–2 syllables per word. A longer name built from short words beats a shorter name that hides meaning. No abbreviations (`cmd`, `args`, `dir`, `xfrm`).

- **Variables** use `UPPER_CASE` — top-level settings and run state, and locals inside functions.
- **Functions** use `lower_case`.

**Files, folders, and paths** — use a suffix that matches what the variable holds:

| Suffix | Holds |
|--------|--------|
| `_FILE` | A file |
| `_FOLDER` | A folder |
| `_SCRIPT` | Path to an executable or script file (run with `sh` when not executable) |

Do not use `_FILE` for a folder.

**Session folder and on-disk file names** use **camelCase** (e.g. `exitCode`, not `exit_code`). Shell variables that hold paths use `UPPER_CASE` with `_FILE`, `_FOLDER`, or `_SCRIPT` suffixes.

**Call-site readability comes first** in function and predicate names. Env vars and settings may be longer or use a different word when that reads better at the point of use.

**Do not shadow top-level variables.** Function bodies must not assign to globals from parameters. Use `$1`, `$2`, or different local names inside helpers.

**Exception:** external tool names and flags (`llama-completion`, `-no-cnv`).

## Settings and CLI

Every **user-facing setting** has **both** an environment variable and a long-form CLI flag. The flag overrides the env var when set on the command line.

Document each pair in `-h`: what the flag does under **Options**; env name linked to flag under **Environment Variables**. Add both when you add a new setting.

Short CLI forms are rare (`-h`, `-m` only). Internal run state (loop counters, session paths, etc.) is not a setting.

## Error messages

When the user can fix a failure by changing a **user-facing setting**, say how: the **CLI flag** (include short forms like `-m` when they exist) and the matching **`SSA_*` or helper env var**. Follow the pattern in `check_model_runner()` in [`libexec/ssa/ssa.sh`](../libexec/ssa/ssa.sh):

```sh
util_die "model runner not set; use --model-runner or " \
    "SSA_MODEL_RUNNER (e.g. /path/to/libexec/ssa/llamaCppRunner.sh)"
```

This applies to **startup validation and runtime failures alike** — e.g. retries exhausted because a limit was reached should hint `SSA_MAX_CURL_CALLS` when raising that cap may help.

When the setting was provided but the path or value is wrong, name the same flag/env pair (`… not found: $path; use …`).

Settings with **no harness CLI flag** (e.g. `SSA_SANDBOX_USER`, `SSA_MAX_CURL_CALLS` in [curlRunner.sh](../libexec/ssa/curlRunner.sh)) should name the env var and point to `ssa -h` when useful. Do not say `export` — assume shell users know how to set variables.

Keep hints **one short clause** after a semicolon (`; SSA_MAX_CURL_CALLS …`, `; use -m …`). Do not restate the whole header.

**Skip hints** only when there is no user setting to change: internal harness failures (transcript I/O, session folder setup), missing OS tools on `PATH`, or failures fixed outside ssa (install a package, fix API billing).

The task has **no env var** — say to pass words after options or pipe stdin.

Harness and helpers use `util_die` from [utils.sh](../libexec/ssa/utils.sh) on stderr. `util_die` sends SIGUSR1 to `ssa` via `SSA_PID`. Other harness or script-runner messages use plain `printf … >&2`; do not use `basename "$0"` for user-facing diagnostics.

**Message layout.** For `util_die` and similar diagnostics, the opening quote starts on the **same line** as the command — not on a continuation line after `\`. Wrap long messages at **80 columns** using adjacent quoted parts; the first `"` stays on the command line. Use `\` at end of line when the wrapped parts must stay one command:

```sh
util_die "model runner not executable or readable: $SSA_MODEL_RUNNER; " \
    "use --model-runner or SSA_MODEL_RUNNER"
```

Short messages stay on one line:

```sh
util_die "cannot write transcript"
```

Do not put the whole message alone on the line below the command.

## Status codes

Control-flow numbers used for **`return`** and loop status are **named constants** at the top of the script — not magic numbers in function bodies.

For other numeric literals, use an **intent-clarifying name** when the value is not obvious at the call site (e.g. `DEFAULT_RETRY_SLEEP_SECONDS=5`). Obvious values (`0`, `1`, `200`/`300`/`429` for HTTP, `700` for `chmod`) may stay inline.

Group constants by role. Use verb-phrase names when they read clearly at `return`.

Predicate functions used in `if name; then` return **0 when the named condition holds** — not loop or retry codes. Use a separate set of constants for predicates vs loop control when both exist.

**Keep predicates pure.** Functions used as `if name; then` tests should only inspect state and return `IS_TRUE` / `IS_FALSE`. No logging, transcript updates, prompts, or other side effects — put those in the caller's `then` / `else` body.

**Exception:** interactive script runners (e.g. [askUserSandbox.sh](../libexec/ssa/askUserSandbox.sh)) may read `/dev/tty` for user input; do not use them as models for parse predicates.

Use `return $CONSTANT_NAME`, not `return CONSTANT_NAME` (no `$` treats the name as a command).

## Globals and locals

Use `UPPER_CASE` for any shell variable. Keep locals inside the function that uses them.

**Do not pass run globals as arguments** when the callee can read them directly.

## Functions

- **One clear job per function.** Split when a body is hard to scan.
- **Thin glue** — extract a helper when the name clarifies intent. Do not wrap a single `printf` + `exit` or a single assignment unless it is reused.
- **Prefer `if`** over `[ test ] && command` when a test selects among several actions or branches. A single action may use one line: `if [ test ]; then command; fi`.
- **Guard + `util_die`** — when the only action on failure is `util_die`, use `||`: `[ -n "$VAR" ] || util_die "…"`, `command || util_die "…"`. Sequential steps that must all succeed may use `&&` ending in `|| util_die`.
- Keep `||` on **`read`** loops and similar idioms where it is not action selection.
- **`case` arms** — prefer one line: `pattern) action ;;`. Split across lines only when the arm would exceed 80 columns (wrap the action with `\` or adjacent quoted parts as elsewhere).

## Static strings

Long static text (prompts, help, errors) lives in **top-level variables**, not inside functions.

Short **grep** patterns and literals used in one function may live as named locals there; inline short literals at the comparison when they read clearly. **sed** programs are hard to scan — always give them a named local (or top-level name when shared) so the call site states intent; do not inline sed program strings in the `sed` command.

Split fully static text from parts that need substitution. Functions that use those strings should be thin glue: `printf`, swap-in, little else. No big heredocs inside functions when the text is mostly fixed.

## Line length

**Maximum 80 characters per line** in `*.sh` source (including static strings, comments, and code).

When a line would exceed 80 characters, break it: shell line continuation (`\` at end of line), split a top-level string across several quoted lines, or use multiple `printf` calls. Do not shorten names just to fit; wrap instead.

**Exception:** external tool command lines where flags must stay as-is (e.g. `llama-completion` invocations).

## Quoting

Quote **string literals** in assignments and in `[ ]` / `=` comparisons:

```sh
SSA_LOOP_STATUS="done"
[ "$(cat "$SSA_PARSED_SCRIPT_FILE")" = "echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT" ]
```

Leave **unquoted**:

- **Numeric constants and status codes** — `SSA_LOOP_AGAIN=0`, `return $SSA_TRY_AGAIN`, `SSA_KEEP_SESSION=1`
- **`case` patterns** — CLI flags (`-h|--help)`), interactive answers (`y|Y|yes|YES)`)
- **Signal names in `trap`** — `trap '…' EXIT INT TERM USR1` (USR1 for `util_die`; INT/TERM for external cancel)

Top-level static strings use single- or double-quoted `VAR='…'` / `VAR="…"` as today.

## Streams

- **stdout** — interleaved script output live during each run (harness `2>&1 | tee`) and requested help (`-h`, `--help`).
- **stderr** — harness errors, helper errors, and the final status line. Use `>&2` for agent meta-messages. Script runners do not merge script stderr into stdout; the harness does. Do not capture stdout in `$()` unless you want script output or help text.

## File order

**Follow the call graph.** Function placement is driven by who calls whom, not by grouping helpers at the bottom because they look similar (e.g. do not park `show_help_and_exit` next to `util_die` unless that is where the last caller sits).

Within a script file:

1. Settings, run state, and static strings
2. `main()` first (after settings and strings), then its callees and their callees in **call order**
3. `main "$@"` on the last line

Rules:

- Each function sits **below its last caller** (reading top to bottom).
- If two callers share a helper, place it under whichever caller appears **last** in the file.
- Among callees of the same caller, keep **call order** (e.g. order in a `case` arm list or in the caller body).
- Shared low-level helpers still follow the same rule: under their **last** caller, not under an arbitrary “utilities” section.

Split into more `*.sh` files only when one file is hard to read — and only if the 1,000-line max in [DESIGN.md](DESIGN.md#line-budget) allows.

## Shell use

**The agent is invoked like any Unix util.** Do not add flags or env vars for behavior the caller’s shell can handle in one line at the call site.

### In the agent (do not duplicate in docs as “user steps”)

Only what the loop needs: parse task, call model filter, extract ` ```ssa_script ` block, run it, append to transcript, optional extra scripts.

### At the call site (user’s job)

| Need | Shell, not agent |
|------|------------------|
| Working directory | `cd` before `ssa` |
| Environment | `export VAR=value` or `VAR=value ssa …` |
| Diagnostic log file | `ssa … 2>run.log` |
| Durable transcript / session | `--keep-session`, `SSA_KEEP_SESSION=1`, or inspect `$TMPDIR/ssa-$LOGNAME-*` while running |
| Dirs for your script paths | `mkdir -p` before the run |
| Model inference | `--model-runner PATH` or `export SSA_MODEL_RUNNER=…` |
| Repeat for many tasks | `for task in …; do …; done` |

When reviewing changes to `libexec/ssa/ssa.sh`, ask: *could the user do this with `cd`, `export`, or a redirect?* If yes, leave it out of the agent.

**User-provided paths** (`SSA_MODEL_RUNNER`, `SSA_SCRIPT_RUNNER`, etc.): the agent does not create parent directories or otherwise prepare those files for you. Create directories and ensure paths are writable before you run the agent.

For how to run the agent, CLI flags, env settings, and error handling, see `ssa -h`, [DESIGN.md](DESIGN.md), and [README.md](README.md).
