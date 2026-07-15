# Offline tests for `singleFileVersion/ssa`

How to exercise the single-file harness without a network or a real model
provider. These tests are adapted from `libexec/ssa/community/` for the
built-in curl client and the single-file CLI/settings names.

## Run

From the repo root (Git Bash / WSL / any POSIX `sh`):

```sh
sh singleFileVersion/tests/runTests.sh
```

A single case can be run alone:

```sh
sh singleFileVersion/tests/happyPath.test.sh
```

The suite prints `PASS` / `FAIL` per case and exits non-zero if any fail.

## Layout

| Path | Role |
|------|------|
| `singleFileVersion/tests/runTests.sh` | Entry point; sources every `*.test.sh` |
| `singleFileVersion/tests/testUtils.sh` | Shared setup, `run_ssa`, assertions |
| `singleFileVersion/tests/fakeCurl.sh` | Offline stand-in for `curl` |
| `singleFileVersion/tests/stubSandboxCommand.sh` | Offline `--sandbox-command` |
| `singleFileVersion/tests/*.test.sh` | One case per file |

`singleFileVersion/ssa` is not modified for tests. Offline responses come from
putting `fakeCurl.sh` on `PATH` as `curl` for each case.

## How fake curl works

`run_ssa` installs `fakeCurl.sh` as `$CASE_FOLDER/bin/curl` and prepends that
directory to `PATH`, so the harness’s real `curl` invocations hit the stub.

On each call the stub:

1. Bumps a counter file under `SSA_STUB_REPLIES_FOLDER`
2. Loads `replyN.txt` for that count (`reply1.txt` on the first HTTP call)
3. Wraps the file contents as OpenAI-style
   `{choices:[{message:{content:…}}]}` via `jq`
4. Writes the JSON to curl’s `-o` file, headers to `-D`, and prints `200`
   for `-w '%{http_code}'`

The fake-first bootstrap turn in `ssa` does not call curl, so `reply1.txt` is
the first **model** prompt (`prompt1/`).

If the first line of a reply file is exactly `CURL_FAIL`, the stub exits
non-zero (simulates a curl failure).

## How cases drive the harness

- Task on argv by default; set `RUN_STDIN_FILE` to pipe a task instead
- Private `TMPDIR` per case so temp folders do not collide
- Default `run_ssa` sets `SSA_NO_ASK=1`, `--no-ask`, a dummy `OPENAI_URL`,
  and `SSA_MODEL=stubModel`
- Status line text uses **model prompts** (not multi-file “model calls”)
- Keep temp with `--keep-temp`; transcript file is `fullTranscript.txt`
- Script-runner coverage uses `--sandbox-command` and
  `stubSandboxCommand.sh` (marker `STUB_SANDBOX_COMMAND_RAN`)

## Case catalog

| File | What it checks |
|------|----------------|
| `happyPath.test.sh` | One scripted turn, then done sentinel; exit 0 |
| `formatErrorsRetry.test.sh` | Bad fences / empty script; three format errors then done |
| `doneEdgeCases.test.sh` | Done is exact full-string match (padding runs as a script) |
| `maxModelPrompts.test.sh` | `--max-model-prompts 1` → exit 1 + hit-max line |
| `taskFromArgv.test.sh` | Argv task words land in kept transcript |
| `taskFromStdin.test.sh` | Stdin task words land in kept transcript |
| `streamAndTranscript.test.sh` | Script stdout + sandbox-command marker + transcript |
| `missingOpenAIUrl.test.sh` | Missing `OPENAI_URL` fails at startup |

## Writing a new case

1. Add `singleFileVersion/tests/yourName.test.sh`
2. Source `testUtils.sh`, define `test_*`, call `run_test` and
   `finish_if_standalone`
3. Drop reply files via `write_script_reply` (or heredocs for invalid shapes)
4. Prefer `run_ssa` unless you need custom env (see stream / missing-URL cases)

`runTests.sh` picks up any new `*.test.sh` under the tests folder automatically.
