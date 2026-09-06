#!/bin/sh
# First line "# edit file:" with no path is not an edit request; it
# is a format error, not a script.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# edit file:
echo empty-path-was-script
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

run_ssa_task treat empty edit path as a script
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'Format error'
expect_stdout_lacks 'empty-path-was-script'
expect_stdout_lacks 'edited file:'
