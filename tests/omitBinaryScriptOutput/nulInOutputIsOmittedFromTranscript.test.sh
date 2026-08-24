#!/bin/sh
# A script that prints a NUL is not appended as raw bytes; the loop
# continues with a short omit note in messages.json.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf '\0'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task --keep-temp print a nul then stop
expect_exit 0
expect_stderr_has 'done: task complete after 2 model prompts'
expect_stdout_lacks 'Output omitted:'

NUL_COUNT=$(tr -cd '\0' <"$TEST_TEMP_FOLDER/stdout.txt" | wc -c)
[ "$NUL_COUNT" -ge 1 ] || fail "stdout should keep the NUL bytes"

MESSAGES="$(get_kept_ssa_folder)/prompt2/messages.json"
[ -f "$MESSAGES" ] || fail "missing prompt snapshot: $MESSAGES"
jq -e '.' "$MESSAGES" >/dev/null ||
    fail "messages.json should stay valid JSON"
MSG_NUL=$(tr -cd '\0' <"$MESSAGES" | wc -c)
[ "$MSG_NUL" -eq 0 ] || fail "messages.json should not contain NUL"
jq -r '.[].content' "$MESSAGES" | grep -qF \
    'Output omitted: not valid UTF-8' ||
    fail "user turn should omit NUL output"
jq -r '.[].content' "$MESSAGES" | grep -qF \
    'Output from running the script:' ||
    fail "UTF-8 script output should still be in the transcript"
