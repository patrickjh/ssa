#!/bin/sh
# testUtils.sh — helpers for story tests (sourced by *.test.sh).
# Defines functions only; does nothing when sourced.
# Expects runTests.sh to have exported TEST_TEMP_FOLDER and
# TEST_UTILS_FILE.

fail() {
    printf '%s\n' "$1" >&2
    exit 1
}

require_test_temp_folder() {
    [ -n "${TEST_TEMP_FOLDER:-}" ] ||
        fail "TEST_TEMP_FOLDER not set; run via tests/runTests.sh"
}

get_ssa_path() {
    [ -n "${TEST_UTILS_FILE:-}" ] ||
        fail "TEST_UTILS_FILE not set; run via tests/runTests.sh"
    SSA_PATH=$(CDPATH= cd -- "$(dirname "$TEST_UTILS_FILE")/.." && pwd)/ssa ||
        fail "cannot resolve ssa"
    [ -f "$SSA_PATH" ] || fail "not found: $SSA_PATH"
    printf '%s\n' "$SSA_PATH"
}

run_ssa() {
    require_test_temp_folder
    sh "$(get_ssa_path)" "$@" \
        </dev/null \
        >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
    SSA_EXIT_CODE=$?
}

expect_exit() {
    [ "${SSA_EXIT_CODE-}" = "$1" ] ||
        fail "expected exit $1, got ${SSA_EXIT_CODE-}"
}

expect_stdout_has() {
    require_test_temp_folder
    grep -qF -- "$1" "$TEST_TEMP_FOLDER/stdout.txt" ||
        fail "stdout missing: $1"
}

expect_stdout_lacks() {
    require_test_temp_folder
    if grep -qF -- "$1" "$TEST_TEMP_FOLDER/stdout.txt"; then
        fail "stdout should not contain: $1"
    fi
}

expect_stderr_empty() {
    require_test_temp_folder
    [ ! -s "$TEST_TEMP_FOLDER/stderr.txt" ] ||
        fail "stderr should be empty"
}

expect_stderr_has() {
    require_test_temp_folder
    grep -qF -- "$1" "$TEST_TEMP_FOLDER/stderr.txt" ||
        fail "stderr missing: $1"
}

expect_file_equals() {
    # $1 = actual file, $2 = expected file
    [ -f "$1" ] || fail "file not found: $1"
    cmp -s "$1" "$2" || fail "file differs from expected: $1"
}

expect_no_file() {
    [ ! -e "$1" ] || fail "should not exist: $1"
}

setup_fake_model() {
    # Puts a fake curl on PATH that serves canned chat-completions JSON
    # from REPLIES_FOLDER (reply1.txt, reply2.txt, …) in order.
    require_test_temp_folder
    REPLIES_FOLDER="$TEST_TEMP_FOLDER/replies"
    FAKE_COMMANDS_FOLDER="$TEST_TEMP_FOLDER/fakeCommands"
    mkdir -p "$REPLIES_FOLDER" "$FAKE_COMMANDS_FOLDER" ||
        fail "cannot create fake model folders"
    write_fake_curl_script "$FAKE_COMMANDS_FOLDER/curl"
    PATH="$FAKE_COMMANDS_FOLDER:$PATH"
    export PATH
    SSA_TEST_REPLIES_FOLDER="$REPLIES_FOLDER"
    export SSA_TEST_REPLIES_FOLDER
}

write_fake_curl_script() {
    cat >"$1" <<'FAKE_CURL' || fail "cannot write fake curl script"
#!/bin/sh
# Fake curl for tests: serves canned chat-completions JSON in order.
set -u
[ -n "${SSA_TEST_REPLIES_FOLDER:-}" ] || {
    printf 'fake curl: SSA_TEST_REPLIES_FOLDER not set\n' >&2
    exit 1
}
COUNT_FILE="$SSA_TEST_REPLIES_FOLDER/curlCount.txt"
COUNT=0
if [ -f "$COUNT_FILE" ]; then COUNT=$(cat "$COUNT_FILE"); fi
COUNT=$((COUNT + 1))
printf '%s\n' "$COUNT" >"$COUNT_FILE" || exit 1
REPLY_FILE="$SSA_TEST_REPLIES_FOLDER/reply${COUNT}.txt"
[ -f "$REPLY_FILE" ] || {
    printf 'fake curl: no canned reply: %s\n' "$REPLY_FILE" >&2
    exit 1
}
OUT_FILE=""
HEADERS_FILE=""
PREV=""
for ARG in "$@"; do
    if [ "$PREV" = "-o" ]; then OUT_FILE=$ARG; fi
    if [ "$PREV" = "-D" ]; then HEADERS_FILE=$ARG; fi
    PREV=$ARG
done
[ -n "$OUT_FILE" ] || {
    printf 'fake curl: missing -o output file\n' >&2
    exit 1
}
cp "$REPLY_FILE" "$OUT_FILE" || exit 1
if [ -n "$HEADERS_FILE" ]; then
    printf 'HTTP/1.1 200 OK\r\n\r\n' >"$HEADERS_FILE" || exit 1
fi
printf '200'
exit 0
FAKE_CURL
    chmod +x "$1" || fail "cannot make fake curl executable"
}

add_model_reply() {
    # $1 = reply number. Raw model reply text on stdin; wrapped as
    # chat-completions JSON for the fake curl to serve.
    [ -n "${REPLIES_FOLDER:-}" ] || fail "call setup_fake_model first"
    jq -Rs '{choices: [{message: {content: .}}]}' \
        >"$REPLIES_FOLDER/reply$1.txt" ||
        fail "cannot write canned reply $1"
}

setup_work_folder() {
    # Folder the agent runs in; model scripts touch files here.
    require_test_temp_folder
    WORK_FOLDER="$TEST_TEMP_FOLDER/work"
    mkdir -p "$WORK_FOLDER" || fail "cannot create work folder"
}

run_ssa_task() {
    # Run an agent loop against the fake model, from WORK_FOLDER.
    require_test_temp_folder
    [ -n "${WORK_FOLDER:-}" ] || fail "call setup_work_folder first"
    ( cd "$WORK_FOLDER" && sh "$(get_ssa_path)" \
        --openai-url 'http://fake.test/chat/completions' \
        --model fakeModel --no-ask "$@" ) \
        </dev/null \
        >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
    SSA_EXIT_CODE=$?
}

run_ssa_task_from_stdin() {
    # Like run_ssa_task, but the task is stdin (no argv words).
    require_test_temp_folder
    [ -n "${WORK_FOLDER:-}" ] || fail "call setup_work_folder first"
    ( cd "$WORK_FOLDER" && sh "$(get_ssa_path)" \
        --openai-url 'http://fake.test/chat/completions' \
        --model fakeModel --no-ask "$@" ) \
        >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
    SSA_EXIT_CODE=$?
}
