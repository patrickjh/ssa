#!/bin/sh
# Write request path may contain spaces; the path is $0 of -c.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file: my file.txt
hello from a spaced path
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

cat >"$TEST_TEMP_FOLDER/expected.txt" <<'EXPECTED'
hello from a spaced path
EXPECTED

run_ssa_task create my file.txt
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'wrote file: my file.txt'
expect_file_equals "$WORK_FOLDER/my file.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
