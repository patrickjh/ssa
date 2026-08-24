#!/bin/sh
# -m as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa -m
expect_exit 1
expect_stderr_has '-m / --model found with empty value'
expect_stderr_has 'see ssa -h for help'
