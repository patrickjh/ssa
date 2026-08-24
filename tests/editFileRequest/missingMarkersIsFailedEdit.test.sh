#!/bin/sh
# Missing SEARCH/REPLACE markers is a failed edit, not a format error;
# the loop continues and a later valid edit succeeds.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'alpha\n' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
this is not a SEARCH/REPLACE block
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
# task complete
REPLY

printf 'gamma\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task edit notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 3 model prompts'
expect_stdout_has 'edit failed:'
expect_stdout_has 'missing SEARCH/REPLACE markers'
expect_stdout_lacks 'Format error'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
