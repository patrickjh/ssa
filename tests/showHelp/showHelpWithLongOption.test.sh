#!/bin/sh
# Help text on stdout when invoked with --help.

set -u
. "$TEST_UTILS_FILE"

run_ssa --help
expect_exit 0
expect_stdout_has '-h, --help'
expect_stdout_has 'SSA_URL'
expect_stderr_empty
