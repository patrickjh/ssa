#!/bin/sh
# "# script" with no program after it is a format error.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# script
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stderr_has 'done: after 2 model prompts'
