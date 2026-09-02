#!/bin/sh
# Edit request path may contain spaces; the path is $0 of -c.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'hello\n' >"$WORK_FOLDER/my file.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: my file.txt
<<<<<<< SEARCH
hello
=======
hello from a spaced path
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

printf 'hello from a spaced path\n' \
    >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

run_ssa_task edit my file.txt
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'edited file: my file.txt'
expect_file_equals "$WORK_FOLDER/my file.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"
