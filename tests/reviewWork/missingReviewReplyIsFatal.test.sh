#!/bin/sh
# No canned review reply: curl dies; not a silent skip. Exit 1.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

SSA_TEST_NO_REVIEW_REPLY=1 run_ssa_task print a greeting then stop
expect_exit 1
expect_stdout_has 'hello-from-script'
expect_stderr_has 'curl failed'
