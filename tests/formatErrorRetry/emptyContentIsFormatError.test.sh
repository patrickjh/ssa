#!/bin/sh
# HTTP 200 with empty message content is a format error, then the
# model can recover with # task complete.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply_json 1 <<'JSON'
{"choices":[{"message":{"content":""}}]}
JSON

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error: empty reply'
expect_stderr_has 'done: task complete after 2 model prompts'
