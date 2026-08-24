#!/bin/sh
# Empty new string deletes the unique old block.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'keep' 'delete me' 'keep2' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
delete me

=======
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

printf '%s\n' 'keep' 'keep2' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task delete a line from notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
