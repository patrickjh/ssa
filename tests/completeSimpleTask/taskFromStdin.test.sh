#!/bin/sh
# Empty argv; the task is read from stdin.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task_from_stdin <<'TASK'
print a greeting then stop
TASK
expect_exit 0
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: task complete after 2 model prompts'
