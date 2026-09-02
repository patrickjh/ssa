#!/bin/sh
# Old string matching twice is not applied; the file is unchanged.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'same' 'same' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
same
=======
other
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

printf '%s\n' 'same' 'same' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task do not replace a repeated line
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'edit failed:'
expect_stdout_has '2 times (need 1)'
expect_stdout_lacks 'edited file:'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
