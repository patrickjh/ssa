#!/bin/sh
# testTaskFromStdin.sh — task piped on stdin. Same transcript check as
# the argv test, proving the stdin task text reached the prompt.

set -u
COMMUNITY_FOLDER=${COMMUNITY_FOLDER:-$(CDPATH= cd -- \
    "$(dirname "$0")/.." && pwd)}
. "$COMMUNITY_FOLDER/testUtils.sh"

test_task_from_stdin() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    printf 'task-words-came-from-stdin\n' >"$CASE_FOLDER/task.txt"
    RUN_STDIN_FILE="$CASE_FOLDER/task.txt"
    run_ssa --keep-session
    RUN_STDIN_FILE=""
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete' || return 1
    expect_transcript_has 'task-words-came-from-stdin' || return 1
}

run_test 'task from piped stdin' test_task_from_stdin

finish_if_standalone
