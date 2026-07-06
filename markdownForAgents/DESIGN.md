# Design

High-level guide to how the agent works. Project rules: below. Style: [STYLE.md](STYLE.md). Wiring, settings, and names: [`libexec/ssa/ssa.sh`](../libexec/ssa/ssa.sh) (`-h`, `HELP_TEXT`). Public command: [`bin/ssa`](../bin/ssa) (add `bin/` to `PATH`).

## Inspired by mini-swe-agent

[mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent) stays ~100 lines of Python by:

1. Giving the model **only bash** as a tool
2. Running each action in a **new process** (no live shell session)
3. Using a **simple loop** not planners, graphs, or tool lists

This project follows the same ideas in POSIX `sh`, with a 1,000-line max for all shell scripts in the repo ([`bin/ssa`](../bin/ssa) and [`libexec/ssa/*.sh`](../libexec/ssa/)).

## Install layout

Add [`bin/`](../bin/) to `PATH` — only [`ssa`](../bin/ssa) is exposed. That wrapper runs [`libexec/ssa/ssa.sh`](../libexec/ssa/ssa.sh). Bundled runners live under [`libexec/ssa/`](../libexec/ssa/) (not on `PATH`). Set `SSA_MODEL_RUNNER` to the full path of a runner there, or pass `--model-runner` with a full path. To install under a prefix (e.g. `/usr/local`), copy `bin/ssa` to `$prefix/bin/` and `libexec/ssa/*` to `$prefix/libexec/ssa/`.

## Caller’s shell, not built-in features

The harness owns the **agent loop** (prompt, parse, run model scripts, transcript). It does **not** own how you **launch** it. Anything you can do in one or two lines of shell when calling `ssa` should stay in your wrapper — not become a flag or env var in the agent.

Examples: working directory (`cd`), environment (`export`), diagnostic logs (`2>file`), creating parent directories for paths you pass, choosing backends, chaining runs. See [Caller’s shell, not built-in features](#callers-shell-not-built-in-features) and [STYLE.md](STYLE.md#shell-use).

## Program flow

1. **Start** — Parse CLI flags and task (words after options, or stdin when piped), check dependencies, create session files, write the initial transcript.
2. **Loop** — Each iteration runs `call_model_then_run_script`: pipe transcript to the model runner, parse exactly one shell script from the reply, then run it (unless the parsed script is the done script; see Done). Each iteration increments the model-call counter (including runner retries). If the runner exits non-zero, retry the model call without changing the transcript. If a runner or script runner calls `util_die`, it prints on stderr and sends SIGUSR1 to `ssa` (exit `1`; see Stop). If the model call succeeds but the reply has no script, more than one script, or an empty script, retry (parse errors also append feedback to the transcript). Otherwise pipe the script to the script runner (built-in fresh `sh` subshell by default, or `SSA_SCRIPT_RUNNER`); the harness merges script stdout and stderr (`2>&1`), tees the interleaved stream live to the caller’s stdout, and appends the same stream to the transcript (with an output size cap). Any script-runner exit code is the model script result (captured in the transcript; loop continues).
3. **Stop** — Exit `0` when the parsed script’s first non-empty line (whitespace trimmed) is `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`. Exit `1` for harness or usage failures (`util_die`), and when `SSA_MAX_MODEL_CALLS` is reached. Exit `130` or `143` when `ssa` receives SIGINT / SIGTERM; session folder removed unless `--keep-session`. Print a one-line status on stderr only for normal completion (e.g. `done: task complete after N model calls`, or `hit max: stopped after SSA_MAX_MODEL_CALLS (N)`); signal exits omit it.

Session files live under `$TMPDIR/ssa-$LOGNAME-YYYY-MM-DD_HH.MM.SS/` (exported as `SSA_SESSION_FOLDER`). The harness creates that folder with mode `700` (owner-only). Harness working files (`latestModelResponse.txt`, `latestParsedScript.txt`, `latestScriptExitCode.txt`) are overwritten each iteration; `sessionTranscript.txt` spans the whole run and receives script output directly each iteration. Model and script runners write numbered logs grouped by model call, e.g. `prompt3CurlRequest.txt`, `prompt3CurlResponse2.txt` (one file per HTTP retry), `prompt3LlamaCppOutput.txt`, `askUserScript3.txt`. By default the session folder is removed on exit; pass `--keep-session` or set `SSA_KEEP_SESSION=1` to keep it for post-run debugging. Details and names live in `libexec/ssa/ssa.sh`.

The agent never changes its working directory after start. Run it from the folder where model scripts should execute (`cd` first); each script runs in a fresh shell process with that same cwd.

## Exported environment (full-trust default)

At startup, `ssa` **exports** `SSA_PID`, `SSA_MODEL`, `SSA_SESSION_FOLDER`, and `SSA_MODEL_CALLS` (updated each loop iteration). Model and script runners use the latter two for numbered session logs. Harness settings, per-iteration file paths, task text, and other internal state stay private. Model runners, script runners, and default model scripts **inherit** the exported environment — same as any Unix util run as your user. Use `--script-runner` (e.g. [switchUserSandbox.sh](../libexec/ssa/switchUserSandbox.sh), `env -i`) when you want isolation.

## Model interface

No tool-calling APIs or JSON. The model writes plain text plus exactly one ` ```ssa_script ` … ` ``` ` script block per reply.

**Model runner contract** (Unix filter; executable or script):

- **stdin** — full prompt text (`sessionTranscript.txt`: `[SYSTEM]` block, then `[USER]` / `[ASSISTANT]` turns)
- **stdout** — plain-text model reply
- **stderr** — errors only (model backends on failure); backends should not log on success
- **exit code** — `0` = success; non-zero = transient failure (retry same transcript); unrecoverable errors use `util_die` (SIGUSR1 to `ssa`)

**Parse failures** (bad or missing fence) append a `[USER]` error to the transcript, then retry.

**Required:** set `SSA_MODEL_RUNNER` or pass `--model-runner` (executable or script path). If unset, the agent exits at startup (`util_die`). Executables run directly; non-executable paths run with `sh`.

**Bundled model runners** (in [`libexec/ssa/`](../libexec/ssa/)):

- [llamaCppRunner.sh](../libexec/ssa/llamaCppRunner.sh) — spools stdin to `promptNLlamaCppPrompt.txt` (fails if that path exists), runs `llama-completion -f` on it, writes raw output to `promptNLlamaCppOutput.txt`, prints trimmed reply on stdout. Requires `SSA_SESSION_FOLDER` and `SSA_MODEL_CALLS` from `ssa`. Requires `SSA_MODEL` as a GGUF path (from `-m`, `--model`, or env). Checks the file and `llama-completion` on `PATH`; validation lives in the helper, not the agent.
- [curlRunner.sh](../libexec/ssa/curlRunner.sh) — spools stdin to `promptNCurlPrompt.txt` (fails if that path exists), builds JSON in `promptNCurlRequest.txt`, POSTs to an OpenAI-compatible `/chat/completions` endpoint via `curl`. Each HTTP attempt writes `promptNCurlHeadersA.txt`, `promptNCurlResponseA.txt`, `promptNCurlHttpCodeA.txt`, and `promptNCurlExitA.txt` (A = attempt number). Requires `SSA_SESSION_FOLDER` and `SSA_MODEL_CALLS` from `ssa`. Requires `SSA_MODEL` as an API model name (from `-m`, `--model`, or env). Uses `OPENAI_API_KEY` (falls back to `OPENAI_KEY`), `OPENAI_URL`, optional `SSA_CURL_ARGS`, and optional `SSA_MAX_CURL_CALLS` (default 5; see `ssa -h`). Sends the transcript as one `user` message; HTTP `429` with insufficient quota is fatal; other transient HTTP errors retry in the runner (Retry-After header when present, else 5 seconds, up to `SSA_MAX_CURL_CALLS` attempts), then exit fatal if retries are exhausted.

Each runner interprets `SSA_MODEL` for its backend (file path vs API name).

The agent appends `[USER]` / `[ASSISTANT]` sections to the transcript between model calls. Path and environment do not stick between script runs unless the model sets them inline (`cd … &&`, `export … &&`).

## Script runner

Each approved model script is piped to a **script runner** (Unix filter; parallel to the model runner).

**Script runner contract** (executable or script):

- **stdin** — script text (extracted from the model reply)
- **stdout** — model script stdout; runner messages meant for the model (e.g. rejection text)
- **stderr** — model script stderr and runner diagnostics (prompts, notices); the harness merges stdout and stderr for the transcript
- **exit code** — model script result (captured in the transcript; loop continues); unrecoverable errors use `util_die` (SIGTERM to `ssa`)
- **Bad script-runner path** — fatal (`util_die` at startup, like the model runner)

The harness caps captured output (~`SSA_MAX_SCRIPT_OUTPUT_BYTES` via `ulimit -f` in the script-run subshell) for all script runners, built-in and external. Excess output may truncate and fail the script run.

**Default:** built-in path in `invoke_script_runner` — fresh `sh` reading the script from stdin. Inherits exported `SSA_*` env.

**Override:** set `SSA_SCRIPT_RUNNER` to your own executable or script (e.g. seccomp, pledge, `sudo`). Script on stdin; strip or replace env in the runner if you want isolation. Executables run directly; non-executable paths run with `sh`.

**Bundled script runners** (in [`libexec/ssa/`](../libexec/ssa/)):

- [askUserSandbox.sh](../libexec/ssa/askUserSandbox.sh) — shows the script and prompts on stderr; reads `[Y]es / [N]o / [Q]uit` from `/dev/tty` (invalid or empty answers re-prompt). Yes runs the script with `sh`; No prints a rejection message on stdout and exits `1`; Quit calls `util_die`.
- [switchUserSandbox.sh](../libexec/ssa/switchUserSandbox.sh) — reads stdin into a session log, calls `util_die` if empty, else runs the script as **`SSA_SANDBOX_USER`** via `doas` or `sudo` with `sh`. Requires `SSA_SANDBOX_USER` and one-time setup (see the switchUserSandbox header).

## Done

When the parsed script is exactly `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`, the harness stops without running it (see built-in prompts). All other scripts go through the script runner.

## Settings and streams

Most settings use the `SSA_` prefix (defaults and `-h` text are in the script). **`SSA_MODEL_RUNNER` is required** (no default; or `--model-runner`). **CLI flags** (override env when set): `--model-runner`, `--script-runner`, `--max-model-calls`, `-m` / `--model`, `--keep-session`, `--system-prompt`, `--format-error`. Put options before the task. **Task:** words after the last option (multi-word tasks need no quotes; quote tasks that start with `-`), or pipe stdin when not a tty; argv wins if both are set. Short forms: `-h` / `--help`, `-m`. **`SSA_SYSTEM_PROMPT`** (env) holds the full system prompt text; default is built in. **`--system-prompt`** sets prompt text or reads a file when the value is a readable path. **`SSA_FORMAT_ERROR`** (env) is the message appended on parse failure (bad fences or empty script); **`--format-error`** overrides the same way.

The script uses `set -u` only (not `set -e`). Harness failures stop via `util_die`; model script failures are captured and reported, not fatal.

**stdout** streams interleaved script output live during each run (harness `2>&1 | tee`) and `-h` / `--help` text. **stderr** carries messages from `util_die` and the final one-line status on exit `0` or when stopped at max calls. Exit `0` on success; exit `1` on harness or usage failure (`util_die`) or max model calls; exit `130` or `143` on SIGINT / SIGTERM. Redirect stderr to keep a harness log (`2>run.log`).

The session holds the transcript (including system instructions at the top); use `--keep-session` or `SSA_KEEP_SESSION=1` to keep the session folder and helper temp files after the run. At startup, ssa replaces `//SSA_TASK_TOKEN//` with the task from the command line or stdin. Custom system prompts should include that token where the user task should appear. The built-in default includes it and also seeds a real `pwd` script (through the script runner) so the opening transcript shows one prior step.

## User-provided paths

Paths you configure (`SSA_MODEL_RUNNER`, `SSA_SCRIPT_RUNNER`, etc.) are your responsibility: create folders, ensure files exist where required, and make paths writable. The agent only creates its own session folder under `$TMPDIR` (or `/tmp`).

Exported at run time (also visible to model scripts unless a script runner strips env): `SSA_PID`, `SSA_MODEL`. Harness settings, counters, task text, the session folder, and session file paths stay private to the agent loop.

## Project rules

| Rule | Detail |
|------|--------|
| **Language** | POSIX `sh` only for agent logic. No Python, Ruby, Node, etc. |
| **Size cap** | **1,000 lines max** for all shell in the repo ([`bin/ssa`](../bin/ssa), [`libexec/ssa/*.sh`](../libexec/ssa/)). Docs excluded. |
| **Model** | Caller sets `--model-runner` or `SSA_MODEL_RUNNER`. Bundled [llamaCppRunner.sh](../libexec/ssa/llamaCppRunner.sh) (local [llama.cpp](https://github.com/ggml-org/llama.cpp)) and [curlRunner.sh](../libexec/ssa/curlRunner.sh) (OpenAI-compatible HTTP API). |
| **Tools** | Shell only for the model. No custom tool-calling API. |
| **Invocation** | Caller’s shell handles `cd`, `export`, redirects, wrappers — not the agent. |

## Non-goals (for now)

- Re-implementing shell conveniences (logging to arbitrary files, `mkdir` for user paths, cwd management, batch drivers) — use your shell when you call the agent
- Bundled cloud LLM clients inside the agent core (use [curlRunner.sh](../libexec/ssa/curlRunner.sh) or your own runner)
- `llama-server` / HTTP inference paths in the llamaCppRunner helper
- SWE-bench harnesses, Docker/Podman drivers, or multi-env adapters
- YAML/Jinja stacks in the agent (llama-completion handles chat templates in llamaCppRunner)
- GUI, web UI, or IDE plugins

## Done when

1. With `ssa --model-runner /path/to/libexec/ssa/llamaCppRunner.sh`, `-m` (or `SSA_MODEL`), and `llama-completion` on `PATH`, `ssa fix the bug in README` runs locally.
2. With `ssa --model-runner /path/to/libexec/ssa/curlRunner.sh`, `-m` (or `SSA_MODEL`), `curl` + `jq` on `PATH`, and `OPENAI_API_KEY` or `OPENAI_KEY` set, a compatible API run works.
3. A new reader can read the whole agent in one sitting.
4. `wc -l bin/ssa libexec/ssa/*.sh | tail -1` is at most 1,000 (1,000 lines max of POSIX shell).

## Line budget

```sh
wc -l bin/ssa libexec/ssa/*.sh | tail -1
```

When you add features, cut or simplify elsewhere to stay within the 1,000-line max. See [STYLE.md](STYLE.md) for how we keep code clear.
