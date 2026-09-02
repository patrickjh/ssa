#!/bin/sh
# A former setting flag is a bad option, not a task word.

set -u
. "$TEST_UTILS_FILE"

run_ssa --no-ask a task
expect_exit 1
expect_stderr_has 'bad option: --no-ask'
expect_stderr_has 'see ssa -h for help'
