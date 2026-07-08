#!/bin/sh
# testDoneEdgeCases.sh — done detection edge cases.
#
# The code on main (agent_is_done in ssa.sh) treats a script as done only
# when it matches the sentinel string EXACTLY. DESIGN.md describes
# trimming the first non-empty line, but the code does a full-string
# compare with no trimming, so a sentinel with leading/trailing
# whitespace or surrounding blank lines is NOT treated as done — it runs
# as an ordinary script. This test pins that actual contract.

set -u
COMMUNITY_FOLDER=${COMMUNITY_FOLDER:-$(CDPATH= cd -- \
    "$(dirname "$0")/.." && pwd)}
. "$COMMUNITY_FOLDER/testUtils.sh"

test_done_edge_cases() {
    # A sentinel wrapped in blank lines and padded with spaces must NOT
    # trigger done: it runs, printing the sentinel word to stdout, and
    # the loop continues to the next (real) done reply.
    printf 'THOUGHT: padded.\n\n```ssa_script\n\n  %s  \n\n```\n' \
        "$DONE_SENTINEL" >"$REPLIES_FOLDER/reply1.txt"
    write_done_reply "$REPLIES_FOLDER/reply2.txt"
    run_ssa done edge cases
    expect_exit 0 || return 1
    # The padded sentinel ran as a script, so its output reached stdout.
    expect_stdout_has 'COMPLETE_TASK_AND_SUBMIT_FINAL_OUTPUT' || return 1
    # Two model calls means turn 1 was not treated as done.
    expect_stderr_has 'done: task complete after 2 model calls' || return 1
}

run_test 'done detection edge cases (exact-match contract)' \
    test_done_edge_cases

finish_if_standalone
