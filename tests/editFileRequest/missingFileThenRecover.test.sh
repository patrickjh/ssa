#!/bin/sh
# Edit of a missing file fails; the model writes the file, then edits.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
alpha
=======
gamma
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# write file: notes.txt
alpha
REPLY

add_model_reply 3 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
alpha
=======
gamma
>>>>>>> REPLACE
REPLY

add_model_reply 4 <<'REPLY'
# task complete
REPLY

printf 'gamma\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task create then edit notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 4 model prompts'
expect_stdout_has 'edit failed:'
expect_stdout_has 'file not found'
expect_stdout_has 'wrote file: notes.txt'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
