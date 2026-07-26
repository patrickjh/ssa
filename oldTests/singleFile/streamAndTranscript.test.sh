#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_stream_and_transcript() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" \
        'printf streamed-marker-line\n'
    write_script_reply "$REPLIES_FOLDER/reply2.txt" "$DONE_SENTINEL"
    env PATH="$CASE_BIN_FOLDER:$PATH" \
        TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL="stubModel" \
        SSA_NO_ASK=1 \
        OPENAI_URL="https://example.test/v1/chat/completions" \
        sh "$SSA_SCRIPT" --no-ask --keep-temp \
        --sandbox-command "$STUB_SANDBOX_COMMAND" \
        stream to stdout </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 0 || return 1
    expect_stdout_has 'streamed-marker-line' || return 1
    expect_stdout_has 'STUB_SANDBOX_COMMAND_RAN' || return 1
    expect_transcript_has 'streamed-marker-line' || return 1
}

run_test 'script output streamed and in transcript' \
    test_stream_and_transcript

finish_if_standalone
