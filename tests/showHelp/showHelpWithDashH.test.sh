#!/bin/sh
# Help text on stdout when invoked with -h.

set -u
. "$TEST_UTILS_FILE"

run_ssa -h
expect_exit 0
expect_stdout_has '-h, --help'
expect_stdout_has 'SSA_URL'
expect_stdout_has 'SSA_REQUEST_JSON'
expect_stdout_has 'SSA_CONTEXT'
expect_stdout_has 'think, max_tokens'
expect_stdout_has 'feedback'
expect_stdout_has 'requested help'
expect_stdout_has '# complete'
expect_stdout_has 'SSA_NO_EDITS'
expect_stdout_has 'SSA_NO_WRITES'
expect_stdout_lacks 'SSA_SANDBOX_COMMAND'
expect_stdout_lacks '--sandbox-command'
expect_stderr_empty
