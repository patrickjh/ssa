#!/bin/sh
# A write request whose PATH is an existing directory fails on
# stdout; the directory is unchanged; the loop continues.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

mkdir "$WORK_FOLDER/notes" || fail "cannot create notes directory"
printf 'keep\n' >"$WORK_FOLDER/notes/inside.txt" ||
    fail "cannot seed inside.txt"

add_model_reply 1 <<'REPLY'
# write file: notes
hello
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

printf 'keep\n' >"$TEST_TEMP_FOLDER/expected-inside.txt" ||
    fail "cannot write expected file"

run_ssa_task write into the notes directory
expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has 'Is a directory'
expect_stdout_lacks 'wrote file: notes'
expect_stdout_lacks 'Format error'
[ -d "$WORK_FOLDER/notes" ] || fail "notes should still be a directory"
expect_file_equals "$WORK_FOLDER/notes/inside.txt" \
    "$TEST_TEMP_FOLDER/expected-inside.txt"
for PATH_IN_DIR in "$WORK_FOLDER/notes"/*; do
    [ "$(basename "$PATH_IN_DIR")" = "inside.txt" ] ||
        fail "unexpected path in directory: $PATH_IN_DIR"
done
