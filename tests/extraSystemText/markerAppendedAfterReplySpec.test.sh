#!/bin/sh
# A marker is appended after the reply spec, with # complete first
# and one blank line between them.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# complete
REPLY

MARKER='EXTRA_SYSTEM_MARKER'
SSA_EXTRA_SYSTEM_TEXT="$MARKER" SSA_KEEP_TEMP=1 \
    run_ssa_task print a greeting then stop
expect_exit 0

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
SYSTEM_FILE="$TEST_TEMP_FOLDER/systemContent.txt"
jq -j '.messages[0].content' "$BODY" >"$SYSTEM_FILE.raw" ||
    fail "cannot read system content"
# Drop CR that jq may insert when it prints the string.
tr -d '\r' <"$SYSTEM_FILE.raw" >"$SYSTEM_FILE" ||
    fail "cannot read system content"
grep -qF -- 'These are the valid reply formats:' "$SYSTEM_FILE" ||
    fail "system prompt missing reply spec"
tail -n 3 "$SYSTEM_FILE" >"$TEST_TEMP_FOLDER/systemTail.txt" ||
    fail "cannot read system prompt tail"
printf '%s\n' '# complete' '' "$MARKER" \
    >"$TEST_TEMP_FOLDER/expectedTail.txt" ||
    fail "cannot write expected tail"
cmp -s "$TEST_TEMP_FOLDER/systemTail.txt" \
    "$TEST_TEMP_FOLDER/expectedTail.txt" ||
    fail "extra text should follow # complete after a blank line"
