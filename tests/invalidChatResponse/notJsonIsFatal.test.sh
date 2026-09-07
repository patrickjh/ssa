#!/bin/sh
# HTTP 200 with a non-JSON body is fatal; not a format error.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply_json 1 <<'JSON'
not json
JSON

run_ssa_task print a greeting then stop
expect_exit 1
expect_stderr_has 'invalid chat response'
expect_stdout_lacks 'Format error'
