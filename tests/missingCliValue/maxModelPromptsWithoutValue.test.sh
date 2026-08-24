#!/bin/sh
# --max-model-prompts as the last argument has no value.

set -u
. "$TEST_UTILS_FILE"

run_ssa --max-model-prompts
expect_exit 1
expect_stderr_has '--max-model-prompts found with empty value'
expect_stderr_has 'see ssa -h for help'
