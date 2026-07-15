# Design

`ssa` is a Simple Shell Agent in one POSIX `sh` executable: prompt a model for
shell scripts, run them, feed output back, repeat until done.

Run: `chmod +x ssa` then invoke `./ssa` or put this directory on `PATH`.
Details and defaults: `./ssa -h`. Help (`-h`) is a user overview; it does not
need to list every internal path, edge case, or status nuance. This document
and the code are the full design.

## Goal

Agent loop (prompt → parse one `ssa_script` block → run → transcript → repeat)
in a single file with:

- OpenAI-compatible HTTP via **curl** and **jq** (built in)
- **Ask-user** approval (on by default)
- Optional **Unix sandbox user**
- **Sandbox command** to run the model script (default `sh`; override for
  containers / pledge / jails, etc.)

## Program flow

1. **Start** — Parse CLI and task, validate settings and tools (`curl`, `jq`, …),
   create temp folder, write system prompt and task into the transcript, create
   `prompt0/`, seed with a bootstrap `echo starting the agent` (ask-user
   applies when enabled).
2. **Loop** — For each model prompt (`prompt1+`), copy `fullTranscript.txt` to
   `promptN/transcript.txt` (temp log only), run `call_curl` against the live
   transcript; parse one script; if done marker, stop; else run through ask /
   user / command layers; capture script output, then append it to the
   transcript.
3. **Stop** — Exit `0` when the parsed script is exactly
   `echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT`. Exit `1` on harness failure
   or max model prompts. SIGINT / SIGTERM → `130` / `143`.

Done detection: full script contents must equal that one line (no trim /
first-line logic).

## Environment

Harness state is **not** exported into child processes (`sh`,
`--sandbox-command`, or `sudo`/`doas` children).

Private (not exported): `SSA_PID`, `SSA_PROMPT_COUNTER`, `SSA_TEMP_FOLDER`.
Pipeline subshells inside the harness still see them; model scripts and custom
sandbox commands do not inherit them unless the caller sets them.

`SSA_PID` holds the agent PID at startup for `die` (SIGUSR1). It must
not be replaced with `$$` inside a pipeline subshell.

User-facing settings (`SSA_MODEL`, `SSA_NO_ASK`, …) are normal env/CLI
knobs; see Settings below and `ssa -h`.

## Sandboxing (three layers)

Ask and sandbox user are optional. The sandbox command always runs (default
`sh`). Combine any of the three.

### 1. Ask user — off when `SSA_NO_ASK=1` (default `0`)

- CLI: `--no-ask` sets `1`. Env: `SSA_NO_ASK=0|1`.
- When `0`: show each **model** script on **stderr**; print the
  `[Y]es / [N]o / [Q]uit` prompt on stderr; read the answer from `/dev/tty`.
- Yes → run the script (other layers). No → rejection text on stdout, status
  `1` (loop continues). Quit → `die`.
- Invalid answers print `invalid input: …` on stderr and re-prompt.
- Answers are logged to `promptN/userAnswer.txt` when ask runs.
- Requires a readable `/dev/tty` when ask is enabled. Batch jobs: `--no-ask` or
  `SSA_NO_ASK=1`.

### 2. Sandbox user — `SSA_SANDBOX_USER` (default empty)

- CLI: `--sandbox-user USER` (login **name or numeric UID**).
- When set: validate with `id` (exists, not root, not the current UID),
  require `sudo` or `doas`, then run the sandbox command as that user.

### 3. Sandbox command — `SSA_SANDBOX_COMMAND` (default `sh`)

- CLI: `--sandbox-command COMMAND`, or leave default `sh`.
- Validated with `command -v` at startup.
- The harness feeds `latestParsedScript.txt` on that command’s **stdin**.
- Contract: stdout/stderr from the run; exit code recorded in the transcript.
  Unrecoverable stop from inside the harness uses `die` (SIGUSR1 to
  `SSA_PID`). Custom sandbox commands do not get `SSA_PID` in their
  environment; use a non-zero exit (and optional signaling) as documented by
  your wrapper if you need to stop the agent.

### How the script is run

After ask (or after ask is disabled), `latestParsedScript.txt` is fed to:

| `SSA_SANDBOX_USER` | Runs |
|--------------------|------|
| unset | `"$SSA_SANDBOX_COMMAND" < latestParsedScript.txt` |
| set | `sudo`/`doas -u USER -- "$SSA_SANDBOX_COMMAND"` with that file on stdin |

User set → **change user, then run the sandbox command**.

## Model (curl)

Built-in OpenAI-compatible `/chat/completions` client:

- Required: `OPENAI_URL` (full `http(s)://…/chat/completions`), `-m` /
  `SSA_MODEL`
- Optional: `OPENAI_API_KEY`, `SSA_CURL_ARGS`, `SSA_MAX_HTTP_REQUESTS`
  (default 5)
- Once per run, writes `OPENAI_URL` to `$SSA_TEMP_FOLDER/openaiUrl.txt`
  and the task to `$SSA_TEMP_FOLDER/task.txt` (log only; transcript seed
  still uses `SSA_TASK`)
- Temp working files include `latestModelResponse.txt`,
  `latestParsedScript.txt`, `latestScriptExitCode.txt`, and
  `latestScriptOutput.txt` (tee’d script output before transcript append).
- Before each **model** prompt (`prompt1+`), the harness copies
  `fullTranscript.txt` to `$SSA_TEMP_FOLDER/promptN/transcript.txt` for
  debugging (`--keep-temp`). `prompt0/` is created for the fake-first
  bootstrap (no curl / no transcript copy). `N` matches `SSA_PROMPT_COUNTER`.
- Per-prompt HTTP logs live under `promptN/` for model prompts: `body.json`,
  and `curlA/` with `headers.txt`, `response.txt`, `httpCode.txt`,
  `exit.txt`
- `call_curl` / jq read the live transcript (`jq --rawfile`); no stdin
  prompt spool
- Sent as one `user` message; retries on transient HTTP errors;
  insufficient-quota `429` is fatal

Non-zero curl exit → retry the loop (next call number gets a fresh
`promptN/transcript.txt` log snapshot).

## Settings summary

| Setting | CLI | Default |
|---------|-----|---------|
| `OPENAI_API_KEY` | `--openai-api-key` | empty (optional) |
| `OPENAI_URL` | `--openai-url` | unset (required) |
| `SSA_CURL_ARGS` | `--curl-args` | empty |
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
