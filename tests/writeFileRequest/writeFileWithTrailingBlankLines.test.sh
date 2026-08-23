#!/bin/sh
# Write request payload that ends with a blank line is kept (jq -j
# writes the model string as-is; no $(...) stripping).

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file: notes.txt
hello

REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

printf 'hello\n\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task write notes.txt with a trailing blank line
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'wrote file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" "$TEST_TEMP_FOLDER/expected.txt"
