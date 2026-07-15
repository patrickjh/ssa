#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_done_edge_cases() {
    printf 'THOUGHT: padded.\n\n```ssa_script\n\n  %s  \n\n```\n' \
        "$DONE_SENTINEL" >"$REPLIES_FOLDER/reply1.txt"
    write_script_reply "$REPLIES_FOLDER/reply2.txt" "$DONE_SENTINEL"
    run_ssa done edge cases
    expect_exit 0 || return 1
    expect_stdout_has 'COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT' || return 1
    expect_stderr_has 'done: task complete after 2 model prompts' ||
        return 1
}

run_test 'done detection edge cases (exact-match contract)' \
    test_done_edge_cases

finish_if_standalone
