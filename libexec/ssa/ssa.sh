#!/bin/sh
# ssa.sh — Simple Shell Agent main file (POSIX sh).
# See ../README.md and ../markdownForAgents/*.md for details.
# Usage: ssa [options] task words...
# Options and environment: run ssa -h (HELP_TEXT in this file).

set -u
# bring utility functions into scope
. "$(dirname "$0")/utils.sh"

# --- exported to model runners, script runners, and model scripts ---
export SSA_PID=$$  # agent pid; util_die sends SIGUSR1 here
export SSA_MODEL="${SSA_MODEL:-}"  # model name or GGUF path
export SSA_SESSION_FOLDER=""  # temp folder with per-run session state
export SSA_MODEL_CALLS=0  # model-call index; updated each loop iteration

# --- private ---
SSA_MAX_SCRIPT_OUTPUT_BYTES=50000
ULIMIT_BYTES_PER_BLOCK=512
ULIMIT_BLOCK_ROUNDING=511
SSA_MAX_MODEL_CALLS="${SSA_MAX_MODEL_CALLS:-20}"
SSA_MODEL_RUNNER="${SSA_MODEL_RUNNER:-}"
SSA_SCRIPT_RUNNER="${SSA_SCRIPT_RUNNER:-}"
SSA_TASK=""
SSA_SESSION_TRANSCRIPT_FILE=""
SSA_MODEL_RESPONSE_FILE=""
SSA_PARSED_SCRIPT_FILE=""
SSA_EXIT_CODE_FILE=""
SSA_KEEP_SESSION="${SSA_KEEP_SESSION:-0}"
SSA_LOOP_STATUS="stopped"
SSA_LOOP_AGAIN=0
SSA_TASK_DONE=1
SSA_HIT_MAX=2
SSA_TRY_AGAIN=1
SSA_PARSE_OK=0
IS_TRUE=0
IS_FALSE=1

HELP_TEXT='Usage: ssa [options] task
       ssa -h | --help

ssa — Simple Shell Agent.
A simple AI agent written in mostly POSIX sh.
Inspired by mini-swe-agent.

Give the agent a task on the command line or pipe the task on stdin.
Requires a model runner (see --model-runner).
Options can be set via command line or environment variables.

The agent loop
The agent prompts the model asking for sh scripts to complete a task.
The model replies with a shell script.
The agent runs the script and shows the model the results.
Repeat until model signals the task is done or --max-model-calls is hit

Options:
  -h, --help
          Show this help and exit.
  -m, --model VALUE
          Model name for the model runner helper to use.
          Built in llamaCppRunner expects a GGUF file path
          Built in curlRunner expects a OpenAI style model name.
          Sets SSA_MODEL.
  --model-runner PATH
          File to handle model inference.
          Is sent the prompt the AI model should reply to on stdin.
          Runs model inference and posts the reply to stdout.
          See libexec/ssa/ for bundled model runners.
          Sets SSA_MODEL_RUNNER.
  --script-runner PATH
          File to sandbox and run scripts the AI creates.
          See Sandboxing section below for details.
          Sets SSA_SCRIPT_RUNNER.
  --keep-session
          Keep per-run temp files after exit. Useful for debugging.
          Sets SSA_KEEP_SESSION to 1.
  --max-model-calls N
          Stop after N model calls (0 = no limit, default is 20).
          Sets SSA_MAX_MODEL_CALLS to N.

Environment:
  SSA_MODEL_RUNNER              See --model-runner.
  SSA_SCRIPT_RUNNER             See --script-runner.
  SSA_MODEL                     See -m / --model.
  SSA_MAX_MODEL_CALLS           See --max-model-calls.
  SSA_KEEP_SESSION              See --keep-session (1 = keep).

  With libexec/ssa/curlRunner.sh:
  OPENAI_API_KEY                Bearer token (optional for local servers).
  OPENAI_URL                    Full …/chat/completions URL (required).
  SSA_CURL_ARGS                 Extra curl flags; unquoted word-split.
  SSA_MAX_CURL_CALLS            Max HTTP attempts per model call (default 5).

  With libexec/ssa/llamaCppRunner.sh:
  LLAMA_CPP_ARGS                Extra llama-completion flags; word-split.

  With libexec/ssa/switchUserSandbox.sh: (See Sandboxing below)
  SSA_SANDBOX_USER              Login user to run scripts as (required).

  Exported at run time to model runners, script runners, and model scripts
  SSA_PID                       Agent pid; util_die sends SIGUSR1 here.
  SSA_MODEL                     Model name (see -m / --model).
  SSA_MODEL_CALLS               Number of calls to AI model so far.
  SSA_SESSION_FOLDER            Per-run session temp folder (see Files).

  Script runners may want to strip these before running scripts.
  CLI flags override environment variables when both are set.

Files:
  $TMPDIR/ssa-$LOGNAME-YYYY-MM-DD_HH.MM.SS/
          Per session temp folder exported as SSA_SESSION_FOLDER.
          Model runners and script runners can use this for logging
          or scratch space. Folder removed on exit unless --keep-session.
          Harness working files:
          sessionTranscript.txt, latestModelResponse.txt,
          latestParsedScript.txt, latestScriptExitCode.txt.

Sandboxing:
  By default we run scripts the AI model sends us with using plain sh.
  This runs the scripts in the current directory as the current user.
  This default is like giving the AI model control of your terminal.
  For obvious reasons you might want to restrict what that AI model can do.

  To apply sandboxing, ssa supports the idea of a Script Runner.
  A Script Runner is any shell script or binary that will run the AIs scripts.
  You set the path to this file with --script-runner or SSA_SCRIPT_RUNNER.
  Our code will send the script from the AI into the Script Runner on stdin.
  We expect Script Runners to run the script with normal stdout and stderr.
  So Script Runners should apply any sandboxing then run the AIs script.
  Use this to apply sandboxing tools like containers / pledge / jails etc.

  We include two simple Script Runners.

  libexec/ssa/askUserSandbox.sh:
  Shows the scripts the AI creates on the terminal.
  Asks the user if the user wants to run that script.
  Only runs the script if the user chooses Yes.

  libexec/ssa/switchUserSandbox.sh:
  Uses sudo or doas to switch to another user before running the scripts.
  This is simple Unix user sandboxing.
  You have to set up a sandbox user to use this.

Exit status:
  0       Task complete; prints a one-line status on stderr.
  1       Failure (bad arguments, harness failure, or max model calls).

Examples:
  export PATH=/path/to/ssa/bin:$PATH
  ssa "Summarize this repo" # once needed environment variables are set
  ssa -m gpt-4o-mini summarize this repo # choose a model

  Using libexec/ssa/curlRunner.sh:
  OPENAI_API_KEY={{your key here}}
  OPENAI_URL=https://api.openai.com/v1/chat/completions
  SSA_MODEL_RUNNER=/path/to/ssa/libexec/ssa/curlRunner.sh
  SSA_MODEL=gpt-4o-mini
  ssa summarize this repo

  Using libexec/ssa/llamaCppRunner.sh:
  LLAMA_CPP_ARGS="--context 8192 --temp 0.7"
  SSA_MODEL_RUNNER=/path/to/ssa/libexec/ssa/llamaCppRunner.sh
  SSA_MODEL=~/models/model.gguf
  ssa summarize this repo
'

SSA_SYSTEM_PROMPT='
[SYSTEM]
You help users solve tasks with POSIX sh. Each turn you get a transcript of
prior commands and their output. Continue from this transcript; earlier steps
may already be there. Reply with one POSIX sh script that is a good next step.
We will run the script and append the results to the transcript. Each reply
must be in a precise format for us to parse and run your shell script. Replies
that do not match this exact format will cause a format error. Following is an
example in the right format with the command to use when you judge the task is
complete. When you judge the task is not done, reply with other commands
instead of the echo but follow the same format. The format is:

THOUGHT: your reasoning here.

```ssa_script
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
```

[USER]
Do this task:

//SSA_TASK_TOKEN//
'
SSA_FAKE_MODEL_RESPONSE='THOUGHT: Confirm the agent is starting.

```ssa_script
echo starting the agent
```
'
SSA_FORMAT_ERROR='
[USER]
Format error: your last reply did not match the required format. In order for
us to parse and then run your POSIX sh scripts, your reply must be in the
correct format. Here is an example of the correct format with the command you
should use when the transcript shows the task is complete. If you are not sure
the task is complete, use this same format with a POSIX sh script that will
help complete the task. Try again and match this format exactly:

THOUGHT: your reasoning here.

```ssa_script
echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT
```
'

main() {
    trap handle_util_die_signal USR1
    parse_arguments "$@"
    read_task_from_stdin_if_needed
    check_can_run
    setup_agent_loop
    run_agent_loop
    finish_agent_loop
}

handle_util_die_signal() {
    if [ "$SSA_KEEP_SESSION" = 0 ]; then
        cleanup_session_folder
    fi
    exit 1
}

parse_arguments() {
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help) printf '%s\n' "$HELP_TEXT"; exit 0 ;;
            --) shift; SSA_TASK=$*; return ;;
            --model-runner) set_model_runner; shift 2 ;;
            --script-runner) set_script_runner; shift 2 ;;
            -m|--model) set_model; shift 2 ;;
            --keep-session) SSA_KEEP_SESSION=1; shift ;;
            --max-model-calls) set_max_model_calls; shift 2 ;;
            -*) util_die "bad option: $1; try ssa --help" ;;
            *) SSA_TASK=$*; return ;;
        esac
    done
}

set_model_runner() {
    [ -n "${2-}" ] ||
        util_die "--model-runner found with empty value"
    SSA_MODEL_RUNNER=$2
}

set_script_runner() {
    [ -n "${2-}" ] ||
        util_die "--script-runner found with empty value"
    SSA_SCRIPT_RUNNER=$2
}

set_model() {
    [ -n "${2-}" ] ||
        util_die "-m / --model found with empty value"
    SSA_MODEL=$2
}

set_max_model_calls() {
    [ -n "${2-}" ] ||
        util_die "--max-model-calls found with empty value"
    SSA_MAX_MODEL_CALLS=$2
}

read_task_from_stdin_if_needed() {
    if [ -n "$SSA_TASK" ]; then return 0; fi
    if [ -t 0 ]; then return 0; fi
    SSA_TASK=$(cat) ||
        util_die "cannot read task from stdin; " \
        "pass words after options or pipe stdin"
}

check_can_run() {
    [ -n "$SSA_TASK" ] ||
        util_die "no task; pass words after options or pipe stdin"
    case $SSA_MAX_MODEL_CALLS in
    *[!0-9]*) util_die "SSA_MAX_MODEL_CALLS must be a non-negative integer; " \
        "use --max-model-calls or SSA_MAX_MODEL_CALLS" ;;
    esac
    check_required_commands
    check_model_runner
    [ -n "$SSA_MODEL" ] ||
        util_die "model not set; use -m / --model or " \
        "SSA_MODEL (e.g. gpt-4o-mini)"
    check_script_runner
}

check_required_commands() {
    command -v date >/dev/null 2>&1 ||
        util_die "date not found on PATH"
    command -v grep >/dev/null 2>&1 ||
        util_die "grep not found on PATH"
    command -v sed >/dev/null 2>&1 ||
        util_die "sed not found on PATH"
    command -v tee >/dev/null 2>&1 ||
        util_die "tee not found on PATH"
}

check_model_runner() {
    [ -n "$SSA_MODEL_RUNNER" ] ||
        util_die "model runner not set; use --model-runner or " \
        "SSA_MODEL_RUNNER (e.g. libexec/ssa/llamaCppRunner.sh)"
    [ -f "$SSA_MODEL_RUNNER" ] ||
        util_die "model runner not found: $SSA_MODEL_RUNNER; " \
        "use --model-runner or SSA_MODEL_RUNNER"
    [ -x "$SSA_MODEL_RUNNER" ] ||
        util_die "model runner not executable: $SSA_MODEL_RUNNER; " \
        "chmod +x, or use --model-runner or SSA_MODEL_RUNNER"
}

check_script_runner() {
    if [ -z "$SSA_SCRIPT_RUNNER" ]; then return 0; fi
    [ -f "$SSA_SCRIPT_RUNNER" ] ||
        util_die "script runner not found: $SSA_SCRIPT_RUNNER; " \
        "use --script-runner or SSA_SCRIPT_RUNNER"
    [ -x "$SSA_SCRIPT_RUNNER" ] ||
        util_die "script runner not executable: $SSA_SCRIPT_RUNNER; " \
        "chmod +x, or use --script-runner or SSA_SCRIPT_RUNNER"
}

setup_agent_loop() {
    setup_session_folder
    setup_transcript_file
    SSA_LOOP_STATUS="stopped"
}

setup_session_folder() {
    SSA_SESSION_FOLDER="${TMPDIR:-/tmp}/ssa-${LOGNAME:-user}-$(date \
        +%Y-%m-%d_%H.%M.%S)"
    mkdir "$SSA_SESSION_FOLDER" || util_die "cannot create session folder"
    chmod 700 "$SSA_SESSION_FOLDER" ||
        util_die "cannot set session folder permissions"
    SSA_SESSION_TRANSCRIPT_FILE="${SSA_SESSION_FOLDER}/sessionTranscript.txt"
    SSA_MODEL_RESPONSE_FILE="${SSA_SESSION_FOLDER}/latestModelResponse.txt"
    SSA_PARSED_SCRIPT_FILE="${SSA_SESSION_FOLDER}/latestParsedScript.txt"
    SSA_EXIT_CODE_FILE="${SSA_SESSION_FOLDER}/latestScriptExitCode.txt"
    if [ "$SSA_KEEP_SESSION" = 0 ]; then
        trap cleanup_session_folder EXIT
        trap 'cleanup_session_folder; exit 130' INT
        trap 'cleanup_session_folder; exit 143' TERM
    fi
}

cleanup_session_folder() {
    if [ -n "$SSA_SESSION_FOLDER" ]; then rm -rf "$SSA_SESSION_FOLDER"; fi
}

setup_transcript_file() {
    printf '%s\n' "$SSA_SYSTEM_PROMPT" >"$SSA_SESSION_TRANSCRIPT_FILE" ||
        util_die "cannot write transcript"
    run_fake_first_turn
    substitute_tokens_in_transcript
}

run_fake_first_turn() {
    printf '%s\n' "$SSA_FAKE_MODEL_RESPONSE" >"$SSA_MODEL_RESPONSE_FILE" ||
        util_die "cannot write fake first turn response"
    parse_model_result
    [ $? -eq "$SSA_PARSE_OK" ] || \
        util_die "internal error: fake first turn response failed to parse"
    run_model_script
}

substitute_tokens_in_transcript() {
    TRANSCRIPT_TEMP_FILE="${SSA_SESSION_TRANSCRIPT_FILE}.tmp"
    if [ "$(grep -cF '//SSA_TASK_TOKEN//' \
        "$SSA_SESSION_TRANSCRIPT_FILE")" -ne 1 ]; then
        util_die "system prompt must contain exactly one //SSA_TASK_TOKEN//; " \
            "edit SSA_SYSTEM_PROMPT in libexec/ssa/ssa.sh"
    fi
    : >"$TRANSCRIPT_TEMP_FILE" || util_die "cannot write transcript"
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        if [ "$LINE" = '//SSA_TASK_TOKEN//' ]; then
            printf '%s\n' "$SSA_TASK" >>"$TRANSCRIPT_TEMP_FILE" ||
                util_die "cannot write transcript"
        else
            printf '%s\n' "$LINE" >>"$TRANSCRIPT_TEMP_FILE" ||
                util_die "cannot write transcript"
        fi
    done <"$SSA_SESSION_TRANSCRIPT_FILE"
    mv "$TRANSCRIPT_TEMP_FILE" "$SSA_SESSION_TRANSCRIPT_FILE" ||
        util_die "cannot write transcript"
}

run_agent_loop() {
    while :; do
        SSA_MODEL_CALLS=$((SSA_MODEL_CALLS + 1))
        call_model_then_run_script
        case $? in
            $SSA_TASK_DONE) SSA_LOOP_STATUS="done"; break ;;
            $SSA_HIT_MAX) SSA_LOOP_STATUS="hit max"; break ;;
            $SSA_LOOP_AGAIN) continue ;;
            *) util_die "unknown loop status $?" ;;
        esac
    done
}

call_model_then_run_script() {
    if over_model_call_limit; then return $SSA_HIT_MAX; fi
    cat "$SSA_SESSION_TRANSCRIPT_FILE" |
        "$SSA_MODEL_RUNNER" >"$SSA_MODEL_RESPONSE_FILE"
    if [ $? -ne 0 ]; then return $SSA_LOOP_AGAIN; fi
    parse_model_result
    if [ $? -ne "$SSA_PARSE_OK" ]; then return $SSA_LOOP_AGAIN; fi
    if agent_is_done; then return $SSA_TASK_DONE
    else run_model_script
    fi
    return $SSA_LOOP_AGAIN
}

over_model_call_limit() {
    if [ "$SSA_MAX_MODEL_CALLS" -le 0 ]; then return $IS_FALSE; fi
    if [ "$SSA_MODEL_CALLS" -gt "$SSA_MAX_MODEL_CALLS" ]; then
        return $IS_TRUE
    fi
    return $IS_FALSE
}

parse_model_result() {
    if [ ! -s "$SSA_MODEL_RESPONSE_FILE" ]; then
        return $SSA_TRY_AGAIN
    fi
    printf '\n[ASSISTANT]\n' >>"$SSA_SESSION_TRANSCRIPT_FILE" &&
    cat "$SSA_MODEL_RESPONSE_FILE" >>"$SSA_SESSION_TRANSCRIPT_FILE" &&
    printf '\n' >>"$SSA_SESSION_TRANSCRIPT_FILE" ||
    util_die "cannot append to transcript"
    if reply_has_single_script_block; then
        extract_script_to_file
    else
        append_format_error_to_transcript
        return $SSA_TRY_AGAIN
    fi
    if [ ! -s "$SSA_PARSED_SCRIPT_FILE" ]; then
        append_format_error_to_transcript
        return $SSA_TRY_AGAIN
    fi
    return $SSA_PARSE_OK
}

reply_has_single_script_block() {
    OPEN_COUNT=0
    CLOSE_COUNT=0
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        if [ "$LINE" = '```ssa_script' ]; then
            OPEN_COUNT=$((OPEN_COUNT + 1))
        fi
        if [ "$LINE" = '```' ]; then
            CLOSE_COUNT=$((CLOSE_COUNT + 1))
        fi
    done <"$SSA_MODEL_RESPONSE_FILE"
    if [ "$OPEN_COUNT" -ne 1 ]; then return $IS_FALSE; fi
    if [ "$CLOSE_COUNT" -ne 1 ]; then return $IS_FALSE; fi
    return $IS_TRUE
}

extract_script_to_file() {
    INSIDE=$IS_FALSE
    : >"$SSA_PARSED_SCRIPT_FILE" ||
        util_die "file error while extracting script"
    while IFS= read -r LINE || [ -n "$LINE" ]; do
        if [ "$LINE" = '```ssa_script' ]; then INSIDE=$IS_TRUE; continue; fi
        if [ "$INSIDE" = "$IS_FALSE" ]; then continue; fi
        if [ "$LINE" = '```' ]; then break; fi
        printf '%s\n' "$LINE" >>"$SSA_PARSED_SCRIPT_FILE" ||
            util_die "file error while extracting script"
    done <"$SSA_MODEL_RESPONSE_FILE"
}

append_format_error_to_transcript() {
    printf '%s' "$SSA_FORMAT_ERROR" >>"$SSA_SESSION_TRANSCRIPT_FILE" ||
        util_die "cannot append to transcript"
}

agent_is_done() {
    if [ "$(cat "$SSA_PARSED_SCRIPT_FILE")" = \
        "echo COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT" ]; then
        return $IS_TRUE
    fi
    return $IS_FALSE
}

run_model_script() {
    printf '\n[USER]\nOutput from running the script:\n\n' \
        >>"$SSA_SESSION_TRANSCRIPT_FILE" ||
        util_die "cannot append to transcript"
    run_script_in_subshell_to_limit_output
    printf '\n\nScript exit code: %s\n' "$(cat "$SSA_EXIT_CODE_FILE")" \
        >>"$SSA_SESSION_TRANSCRIPT_FILE" ||
        util_die "cannot append to transcript"
}

run_script_in_subshell_to_limit_output() {
    (
        use_ulimit_to_limit_output
        (
            cat "$SSA_PARSED_SCRIPT_FILE" | invoke_script_runner 2>&1
            echo $? >"$SSA_EXIT_CODE_FILE" ||
                util_die "cannot write script exit code"
        ) | tee -a "$SSA_SESSION_TRANSCRIPT_FILE"
    )
}

use_ulimit_to_limit_output() {
    ULIMIT_MAX_SCRIPT_OUTPUT_BLOCKS=$(( \
        (SSA_MAX_SCRIPT_OUTPUT_BYTES + ULIMIT_BLOCK_ROUNDING) \
        / ULIMIT_BYTES_PER_BLOCK \
    ))
    ulimit -f "$ULIMIT_MAX_SCRIPT_OUTPUT_BLOCKS" ||
        util_die "ulimit failed to limit output"
}

invoke_script_runner() {
    if [ -z "$SSA_SCRIPT_RUNNER" ]; then
        sh
    else
        "$SSA_SCRIPT_RUNNER"
    fi
}

finish_agent_loop() {
    case $SSA_LOOP_STATUS in
    done) printf 'done: task complete after %s model calls\n' \
        "$SSA_MODEL_CALLS" >&2; exit 0 ;;
    hit\ max) printf 'hit max: stopped after SSA_MAX_MODEL_CALLS (%s)\n' \
        "$SSA_MAX_MODEL_CALLS" >&2; exit 1 ;;
    *) util_die "unknown loop status $SSA_LOOP_STATUS" ;;
    esac
}

main "$@"
