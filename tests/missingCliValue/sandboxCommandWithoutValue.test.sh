#!/bin/sh
# --sandbox-command as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa --sandbox-command
expect_exit 1
expect_stderr_has '--sandbox-command found with empty value'
expect_stderr_has 'see ssa -h for help'
