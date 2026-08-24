#!/bin/sh
# Invalid UTF-8 on stdout must not die the loop. jq may encode it or
# omit it; messages.json stays valid JSON.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf '\377'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task --keep-temp print invalid utf-8 then stop
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_lacks 'Output omitted:'

BAD_COUNT=$(tr -cd '\377' <"$TEST_TEMP_FOLDER/stdout.txt" | wc -c)
[ "$BAD_COUNT" -ge 1 ] ||
    fail "stdout should keep the invalid UTF-8 byte"

MESSAGES="$(get_kept_ssa_folder)/prompt2/messages.json"
[ -f "$MESSAGES" ] || fail "missing prompt snapshot: $MESSAGES"
jq -e '.' "$MESSAGES" >/dev/null ||
    fail "messages.json should stay valid JSON"
