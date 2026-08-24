#!/bin/sh
# Help text on stdout when invoked with -h.

set -u
. "$TEST_UTILS_FILE"

run_ssa -h
expect_exit 0
expect_stdout_has '-h, --help'
expect_stdout_has 'OPENAI_URL'
expect_stdout_has '--request-json'
expect_stdout_has "'{\"max_tokens\":8192,\"think\":false}'"
expect_stderr_empty
