#!/bin/sh
# Leading # notes and blank lines before "# write file: PATH" are not
# part of the file.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# overwrite notes.txt

# write file: notes.txt
hello from a write request
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

printf 'hello from a write request\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task write notes.txt
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'wrote file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
