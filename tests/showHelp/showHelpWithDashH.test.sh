#!/bin/sh
# Help text on stdout when invoked with -h.

set -u
. "$TEST_UTILS_FILE"

run_ssa -h
expect_exit 0
expect_stdout_has '-h, --help'
expect_stdout_has 'OPENAI_URL'
expect_stdout_has 'SSA_REQUEST_JSON'
expect_stdout_has 'SSA_CONTEXT'
expect_stdout_has 'think, max_tokens'
expect_stdout_has 'feedback'
expect_stdout_has 'requested help'
expect_stderr_empty
