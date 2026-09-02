#!/bin/sh
# First line "# write file:" with no path is not a write request; ssa
# runs the reply as a script.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file:
echo empty-path-was-script
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

run_ssa_task treat empty write path as a script
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'empty-path-was-script'
expect_stdout_lacks 'wrote file:'
