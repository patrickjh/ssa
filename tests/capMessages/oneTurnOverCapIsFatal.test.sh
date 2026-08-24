#!/bin/sh
# One script output larger than the cap cannot be trimmed; ssa dies
# instead of sending an oversize messages.json.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
awk 'BEGIN { for (i = 0; i < 140000; i++) printf "x" }'
echo
REPLY

run_ssa_task print a huge blob
expect_exit 1
expect_stderr_has 'one chat turn is larger than the messages cap'
