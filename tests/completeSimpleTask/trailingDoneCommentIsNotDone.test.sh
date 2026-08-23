#!/bin/sh
# A "# task complete" comment after a script is not the done marker;
# the script still runs.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
# task complete
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: task complete after 2 model prompts'
