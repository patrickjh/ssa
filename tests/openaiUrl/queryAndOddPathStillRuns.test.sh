#!/bin/sh
# A URL with a query string and no /chat/completions suffix is not
# rejected at startup; the fake model still runs.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

require_test_temp_folder
( cd "$WORK_FOLDER" && TMPDIR="$TEST_TEMP_FOLDER" \
    OPENAI_URL='http://fake.test/openai?api-version=1' \
    SSA_MODEL=fakeModel SSA_NO_ASK=1 \
    sh "$(get_ssa_path)" print a greeting then stop ) \
    </dev/null \
    >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
SSA_EXIT_CODE=$?

expect_exit 0
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: task complete after 2 model prompts'
