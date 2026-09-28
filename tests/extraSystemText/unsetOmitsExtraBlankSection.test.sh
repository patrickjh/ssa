#!/bin/sh
# Unset SSA_EXTRA_SYSTEM_TEXT leaves intro plus reply spec, with
# no extra blank section after # complete.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# complete
REPLY

SSA_KEEP_TEMP=1 run_ssa_task print a greeting then stop
expect_exit 0

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
SYSTEM_FILE="$TEST_TEMP_FOLDER/systemContent.txt"
jq -j '.messages[0].content' "$BODY" >"$SYSTEM_FILE" ||
    fail "cannot read system content"
FIRST=$(head -n 1 "$SYSTEM_FILE") || fail "cannot read system prompt"
[ "$FIRST" = 'You help users solve tasks with your replies. Each' ] ||
    fail "system prompt should start with the intro"
grep -qF -- 'These are the valid reply formats:' "$SYSTEM_FILE" ||
    fail "system prompt missing reply spec"
LAST=$(tail -n 1 "$SYSTEM_FILE") || fail "cannot read system prompt end"
[ "$LAST" = '# complete' ] ||
    fail "unset extra text should not add a trailing blank section"
