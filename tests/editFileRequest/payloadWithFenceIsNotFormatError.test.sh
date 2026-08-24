#!/bin/sh
# A fence line in the edit payload is file bytes, not a format error.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf 'hello\n' >"$WORK_FOLDER/notes.md" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.md
<<<<<<< SEARCH
hello
=======
```
fenced
```
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

cat >"$TEST_TEMP_FOLDER/expected.md" <<'EXPECTED'
```
fenced
```
EXPECTED

run_ssa_task put a fence in notes.md
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'edited file: notes.md'
expect_stdout_lacks 'Format error'
expect_file_equals "$WORK_FOLDER/notes.md" \
    "$TEST_TEMP_FOLDER/expected.md"
