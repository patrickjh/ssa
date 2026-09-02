#!/bin/sh
# Prose before a script fails sh -n, is not run, then a valid script
# and done marker finish the task.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
I'll print a greeting now.

printf 'should-not-run\n'
REPLY

add_model_reply 2 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 3 <<'REPLY'
# complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error: not valid POSIX sh'
expect_stdout_lacks 'should-not-run'
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: after 3 model prompts'
