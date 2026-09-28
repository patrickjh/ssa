#!/bin/sh
# Percent and backslash in SSA_EXTRA_SYSTEM_TEXT are stored as-is.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# complete
REPLY

LITERAL='100%s \path'
SSA_EXTRA_SYSTEM_TEXT="$LITERAL" SSA_KEEP_TEMP=1 \
    run_ssa_task print a greeting then stop
expect_exit 0

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
SYSTEM_FILE="$TEST_TEMP_FOLDER/systemContent.txt"
jq -j '.messages[0].content' "$BODY" >"$SYSTEM_FILE" ||
    fail "cannot read system content"
grep -qF -- "$LITERAL" "$SYSTEM_FILE" ||
    fail "system prompt should keep percent and backslash literal"
