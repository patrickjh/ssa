#!/bin/sh
# Empty argv is a usage error even when a pipe is open.

set -u
. "$TEST_UTILS_FILE"

run_ssa_from_stdin <<'NOTES'
notes that must not become the task
NOTES
expect_exit 1
expect_stderr_has 'task not found on CLI'
