#!/bin/sh
# --openai-url as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa --openai-url
expect_exit 1
expect_stderr_has '--openai-url found with empty value'
expect_stderr_has 'see ssa -h for help'
