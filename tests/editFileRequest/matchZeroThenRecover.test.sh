#!/bin/sh
# Old string matching 0 times fails; the file is unchanged; a later
# edit with the real old string recovers.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'alpha\n' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
beta
=======
gamma
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
alpha
=======
gamma
>>>>>>> REPLACE
REPLY

add_model_reply 3 <<'REPLY'
# complete
REPLY

printf 'gamma\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task change alpha to gamma
expect_exit 0
expect_stderr_has 'done: after 3 model prompts'
expect_stdout_has 'edit failed:'
expect_stdout_has '0 times (need 1)'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
