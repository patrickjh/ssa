#!/bin/sh
# --request-json as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa --request-json
expect_exit 1
expect_stderr_has '--request-json found with empty value'
expect_stderr_has 'see ssa -h for help'
