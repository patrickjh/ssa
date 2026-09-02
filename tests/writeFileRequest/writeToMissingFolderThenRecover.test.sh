#!/bin/sh
# A write request to a missing parent folder fails visibly; the model
# recovers with a mkdir script turn and a retried write request.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file: src/app/main.c
int main(void) { return 0; }
REPLY

add_model_reply 2 <<'REPLY'
# The write failed because the folder is missing; create it first.
mkdir -p src/app
REPLY

add_model_reply 3 <<'REPLY'
# write file: src/app/main.c
int main(void) { return 0; }
REPLY

add_model_reply 4 <<'REPLY'
# complete
REPLY

printf 'int main(void) { return 0; }\n' \
    >"$TEST_TEMP_FOLDER/expected.c" ||
    fail "cannot write expected file"

run_ssa_task create src/app/main.c
expect_exit 0
expect_stderr_has 'done: after 4 model prompts'
expect_stdout_has 'wrote file: src/app/main.c'
expect_file_equals "$WORK_FOLDER/src/app/main.c" \
    "$TEST_TEMP_FOLDER/expected.c"
