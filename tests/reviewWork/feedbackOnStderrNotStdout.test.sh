#!/bin/sh
# After # complete, review text is on stderr, not stdout.
# Status N is still the agent prompt count.

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

add_model_reply 3 <<'REPLY'
use a write request next time
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'
expect_stdout_lacks 'use a write request next time'
expect_stderr_has 'Feedback from model:'
expect_stderr_has 'use a write request next time'
expect_stderr_has 'done: after 2 model prompts'
