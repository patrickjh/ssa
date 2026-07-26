#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_happy_path() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" \
        'printf happy-path-output\n'
    write_script_reply "$REPLIES_FOLDER/reply2.txt" "$DONE_SENTINEL"
    run_ssa complete the happy path
    expect_exit 0 || return 1
    expect_stdout_has 'happy-path-output' || return 1
    expect_stderr_has 'done: task complete after 2 model prompts' ||
        return 1
}

run_test 'happy path: scripted turn then done sentinel' test_happy_path

finish_if_standalone
