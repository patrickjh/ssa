#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_missing_openai_url() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" "$DONE_SENTINEL"
    env PATH="$CASE_BIN_FOLDER:$PATH" \
        TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL="stubModel" \
        SSA_NO_ASK=1 \
        sh "$SSA_SCRIPT" --no-ask missing url here </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 1 || return 1
    expect_stderr_has 'OPENAI_URL not set' || return 1
}

run_test 'missing OPENAI_URL fails at startup' \
    test_missing_openai_url

finish_if_standalone
