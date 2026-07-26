#!/bin/sh
# showHelp — help text on stdout, no agent run.
# Sourced by tests/runTests.sh.

test_show_help_short() {
    run_ssa -h
    expect_exit 0 || return 1
    expect_stdout_has '-h, --help' || return 1
    expect_stdout_has 'OPENAI_URL' || return 1
    expect_stderr_empty || return 1
}

test_show_help_long() {
    run_ssa --help
    expect_exit 0 || return 1
    expect_stdout_has '-h, --help' || return 1
    expect_stdout_has 'OPENAI_URL' || return 1
    expect_stderr_empty || return 1
}

run_test 'show help with -h' test_show_help_short
run_test 'show help with --help' test_show_help_long
