#!/bin/sh
# Unique SEARCH/REPLACE edits a file; quotes, dollars, and backticks
# in old and new are kept as raw bytes.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'say: "hi" $HOME `date`' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
say: "hi" $HOME `date`
=======
say: "bye" $HOME `date`
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

printf '%s\n' 'say: "bye" $HOME `date`' \
    >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task change the greeting in notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
