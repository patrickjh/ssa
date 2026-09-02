#!/bin/sh
# A script that prints a CR is not filtered on stdout. Ask listing
# is display-only; sandbox bytes stay raw.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'a\rb\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task print a carriage return then stop
expect_exit 0
grep -q "$(printf 'a\rb')" "$TEST_TEMP_FOLDER/stdout.txt" ||
    fail "stdout should contain a raw CR from the script"
expect_stderr_has 'done: task complete after 2 model prompts'
