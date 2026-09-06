#!/bin/sh
# A valid POSIX script without a # script line is a format error.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'should-not-run\n'
REPLY

add_model_reply 2 <<'REPLY'
# script
printf 'hello-from-script\n'
REPLY

add_model_reply 3 <<'REPLY'
# complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_lacks 'should-not-run'
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: after 3 model prompts'
