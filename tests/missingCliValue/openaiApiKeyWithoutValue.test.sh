#!/bin/sh
# --openai-api-key as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa --openai-api-key
expect_exit 1
expect_stderr_has '--openai-api-key found with empty value'
expect_stderr_has 'see ssa -h for help'
