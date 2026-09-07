#!/bin/sh
# One script output larger than the old 131072-byte cap is kept
# and the run can still complete.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 140000; i++) printf "x" }'
echo
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

run_ssa_task print a huge blob
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
