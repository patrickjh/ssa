#!/bin/sh
# testTaskFromArgv.sh — task from argv. Keep the session and grep the
# transcript for the argv words, so the test verifies the task actually
# routed into the prompt (not just that any run reached the done status).

set -u
COMMUNITY_FOLDER=${COMMUNITY_FOLDER:-$(CDPATH= cd -- \
    "$(dirname "$0")/.." && pwd)}
. "$COMMUNITY_FOLDER/testUtils.sh"

test_task_from_argv() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    run_ssa --keep-session task-words-came-from-argv
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete' || return 1
    expect_transcript_has 'task-words-came-from-argv' || return 1
}

run_test 'task from argv' test_task_from_argv

finish_if_standalone
