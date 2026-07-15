#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_task_from_argv() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" "$DONE_SENTINEL"
    run_ssa --keep-temp task-words-came-from-argv
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete' || return 1
    expect_transcript_has 'task-words-came-from-argv' || return 1
}

run_test 'task from argv' test_task_from_argv

finish_if_standalone
