#!/bin/sh
# Model overwrites an existing file with a write request.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'old line one\nold line two\n' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot seed notes.txt"

add_model_reply 1 <<'REPLY'
# write file: notes.txt
new line one
new line two
new line three
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

printf 'new line one\nnew line two\nnew line three\n' \
    >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task rewrite notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'wrote file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" "$TEST_TEMP_FOLDER/expected.txt"
