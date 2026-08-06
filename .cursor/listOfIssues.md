# SSA review issues

This is an actionable backlog from a review of `ssa`, `AGENTS.md`,
`README.md`, and the live tests. Items are ordered roughly by impact.

## High priority

### [x] Keep ask-user UI on stderr and out of the transcript

Fixed: ask approval runs before the `2>&1 | tee` capture. Only the
sandbox command is captured. Rejection text is still teed as script
output for the transcript.

### [x] Fail when `/dev/tty` cannot provide an answer

Fixed: startup opens `/dev/tty` (not only `-r`); a failed ask `read`
dies with the `--no-ask` / `SSA_NO_ASK=1` hint instead of looping on
empty input.

### [x] Prevent terminal control characters from spoofing ask review

Fixed: `print_model_script` pipes through display-only `sed` filters
(CR → `\r`, ESC → `\e`, other non-print except tab → `?`). Sandbox
input file is unchanged.

### [ ] Harden ask listing against Unicode / visual spoofing

Control-byte filtering does not cover bidi marks, homoglyphs, or other
Unicode visual tricks that can still make the ask listing diverge from
a human reading of the script. Decide on a policy later (reject non-ASCII
in ask display, normalize/escape, or document the residual risk).

### [x] Keep the API key out of model scripts and process arguments

Fixed: setup writes `authHeader.txt` for curl `-H @file`, then
`unset OPENAI_API_KEY`. Curl argv no longer carries the bearer token;
sandbox children do not inherit the key. `authHeader.txt` is always
cleared on exit (even with `--keep-temp`). No `OPENAI_API_KEY_FILE`
setting.

## Correctness and reliability

### [ ] Handle missing CLI option values before expanding `$2`

Value-taking options reference `$2` while `set -u` is active. Commands
such as `ssa -m` fail with a raw `unbound variable` error before the
setter can produce its intended usage error.

Guard that at least two arguments remain, or pass `${2-}` to the setter.
Cover every value-taking option with an acceptance test.

### [ ] Make numeric `--sandbox-user` work as documented

Validation with `id` accepts numeric UIDs, but `sudo -u 1001` may treat
`1001` as a login name rather than UID syntax. This can pass startup
validation and fail for every model script.

Resolve the configured name or UID to a canonical login name with
`id -un` before execution, or use the correct tool-specific UID syntax.
Test both a name and numeric UID on a Unix host.

### [ ] Add finite HTTP timeouts and cap retry sleep

Curl currently has no connect or total timeout. A stalled endpoint can
hang forever before retry logic runs. A server can also provide an
arbitrarily large numeric `Retry-After`.

Set defensible default curl timeouts and cap retry sleep. Preserve an
intentional override mechanism if needed.

### [ ] Decide how to handle background children that keep output open

A model script can start a background process that inherits stdout or
stderr. The shell may finish, but `tee` waits forever because the pipe
still has a writer.

This is difficult to solve portably while preserving live streaming.
Document the limitation and recommend a sandbox command with a process
group and wall-clock timeout, or change the capture design.

### [ ] Report empty or malformed successful API responses

An HTTP 2xx response with no usable message content returns to the model
loop without adding any diagnostic to the transcript. The same request
can consume the full prompt budget with no explanation.

Distinguish malformed JSON, missing response fields, and empty content.
Emit a useful error and choose a bounded retry or fatal policy.

### [ ] Handle binary or invalid UTF-8 script output

Script output is appended verbatim to the transcript. A later
`jq --rawfile` can fail on data it cannot represent safely as JSON.

Choose and document a policy: reject binary output with a clear error,
sanitize it, or encode it before adding it to the transcript.

### [ ] Check for an empty HTTP status before numeric comparison

The `*[!0-9]*` case does not match an empty string. An empty
`httpCode.txt` can reach `[ "$CODE" -ge 200 ]` and produce a numeric
comparison error.

Handle `''|*[!0-9]*)` as failure.

### [x] Make fence extraction verify order and preserve script content

Obsolete: replies are raw shell scripts (no `ssa_script` fence parse).
Cancelled in favor of copy-reply-as-script.

### [ ] Decide the exact completion-marker newline contract

`agent_is_done` uses command substitution, which removes trailing
newlines. A marker followed by blank lines therefore counts as complete,
despite `AGENTS.md` saying there is no trimming. Done marker is now
`# task complete`.

Either implement byte-exact comparison or update the documentation and
tests to allow trailing newlines explicitly.

## Documentation consistency

### [ ] Correct temp-log names in help and `AGENTS.md`

- Code creates `curl1/`, `curl2/`, and so on, not `curlA/`.
- Help omits bootstrap `prompt0/`.
- Model prompts use `prompt1+`.

### [ ] Correct the documented HTTP retry behavior

HTTP retries occur inside one model prompt folder as `curl1`, `curl2`,
and so on. Review the statement in `AGENTS.md` that implies a new
`promptN/transcript.txt` snapshot after a non-zero curl exit.

### [ ] Update README layout and testing instructions

README's layout omits `tests/` and archived `oldTests/`. Add the supported
test entry point:

```sh
sh tests/runTests.sh
```

### [ ] Decide whether URL query strings are supported

The URL validator requires the value to end exactly in
`/chat/completions`. This rejects compatible endpoints that require a
query string, including common Azure-style URLs.

Either allow an optional query string or narrow README's statement that
any OpenAI-compatible endpoint works.

### [ ] Clarify successful help exit status

Help documents exit `0` as task completion, but `-h` and `--help` also
exit successfully.

## Test coverage

### [ ] Extend `tests/testUtils.sh`

Add helpers needed by offline agent-loop stories:

- `expect_stderr_has`
- Optional stdin input rather than unconditional `/dev/null`
- Controlled `PATH`, `TMPDIR`, and OpenAI-related environment
- Fake curl with canned OpenAI-compatible replies
- Transcript and kept-temp assertions

Assign `SSA_PATH=$(get_ssa_path)` separately and verify its status before
invoking `sh`; failure inside command substitution should not let the
parent continue with an empty path.

Keep `testUtils.sh` functions-only.

### [ ] Restore high-value offline acceptance stories

Remake these archived `oldTests/singleFile` behaviors under the current
story structure:

1. Complete a simple task / happy path
2. Respect maximum model prompts
3. Reject missing model and URL settings
4. Accept task from argv
5. Accept task from stdin
6. Retry after model format errors
7. Detect the done marker exactly
8. Stream through a custom sandbox command and record the transcript
9. Keep ask UI on stderr and out of the transcript
10. Produce friendly errors for every missing option value
11. Fail cleanly when `/dev/tty` cannot be read
12. Create owner-only temp folders and files

Do not restore obsolete model-runner or multi-file product architecture.

### [ ] Consider a test-runner success summary

The runner intentionally prints failures only. A short count on success
would make it clear that tests were discovered and executed. Keep output
quiet if silent success is a deliberate project convention.

## Style and cleanup

### [ ] Remove the unused `chmod` dependency check

Directory creation now uses `umask 077`; `check_command chmod` is the only
remaining `chmod` reference.

### [ ] Replace magic return statuses with named constants

Several functions return literal `0` or `1`, contrary to the status-code
rule in `AGENTS.md`. Use `IS_TRUE`, `IS_FALSE`, or a more specific named
status where appropriate.

### [ ] Validate `SSA_KEEP_TEMP`

Unlike `SSA_NO_ASK`, any value other than exactly `0` currently keeps
temporary files. Validate `0|1` or document the broader truthy behavior.

### [ ] Normalize minor formatting

- Use four-space indentation in `cleanup_temp_folder`.
- Remove trailing spaces in static help text.
- Revisit the shared call graph between `handle_user_answers` and
  `print_ask_prompt`; putting the prompt at the top of the answer loop
  would make strict call-order layout possible without a shared
  before-and-after dependency.

### [ ] Declare or rename scratch globals

POSIX `sh` has no portable local variables. Names such as `REPLY`,
`API_ERROR`, `HEADER_VALUE`, and `SED_EXTRACT_BETWEEN_FENCES` persist in
the shell. Declare them as internal state or use more explicit names to
avoid accidental reuse.

### [ ] Make private-variable export guarantees robust or narrower

Assigning an inherited exported variable does not necessarily remove its
export attribute. If a caller exported `PID`, `TEMP_FOLDER`, or
another internal name, reassignment may remain exported to model
scripts.

Unset private names before defining them, or narrow the guarantee in
`AGENTS.md`.

### [ ] Consider trapping SIGHUP

INT and TERM clean temporary files, but a terminal hangup may leave a
transcript behind. Add a HUP policy if cleanup-on-hangup is expected.

## Deliberate tradeoffs, not current bugs

- Extra curl flags are left to a `curl` wrapper on `PATH` (no
  `--curl-args`); curl proxy env vars still apply.
- The fake first script is intentionally subject to ask approval.
- Sandbox commands intentionally accept a single executable path; users
  wrap multi-argument sandbox tools in a script.
- A sandbox user can consume a parsed script through an already-open
  stdin descriptor even though the temp folder is mode `0700`.
- PID-suffixed temp folders substantially reduce parallel sub-agent
  collisions.
- Owner-only files and folders created with `umask 077` are appropriate
  because transcripts and API responses may be sensitive.
