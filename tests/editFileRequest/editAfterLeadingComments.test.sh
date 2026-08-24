#!/bin/sh
# Leading # notes and blank lines before "# edit file: PATH" are not
# part of the SEARCH/REPLACE payload.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'old line\n' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# tweak notes.txt

# edit file: notes.txt
<<<<<<< SEARCH
old line
=======
new line
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

printf 'new line\n' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task edit notes.txt
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'edited file: notes.txt'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
