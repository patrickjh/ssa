#!/bin/sh
# Model creates a new file with a write request: first line
# "# write file: PATH", then raw contents full of bytes a heredoc
# or quoting would mangle.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file: hello.c
#include <stdio.h>

int main(void) {
    /* tricky bytes: "quotes" 'single' $HOME `date` \n \\ EOF */
    printf("hello\n");
    return 0;
}
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

cat >"$TEST_TEMP_FOLDER/expected.c" <<'EXPECTED'
#include <stdio.h>

int main(void) {
    /* tricky bytes: "quotes" 'single' $HOME `date` \n \\ EOF */
    printf("hello\n");
    return 0;
}
EXPECTED

run_ssa_task create hello.c with a greeting
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_has 'wrote file: hello.c'
expect_file_equals "$WORK_FOLDER/hello.c" "$TEST_TEMP_FOLDER/expected.c"
