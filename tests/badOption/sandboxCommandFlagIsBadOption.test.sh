#!/bin/sh
# --sandbox-command is a bad option, not a task word.

set -u
. "$TEST_UTILS_FILE"

run_ssa --sandbox-command sh a task
expect_exit 1
expect_stderr_has 'bad option: --sandbox-command'
expect_stderr_has 'see ssa -h for help'
