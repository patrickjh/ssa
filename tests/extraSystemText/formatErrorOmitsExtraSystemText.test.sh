#!/bin/sh
# An empty reply is a format error. That turn reprints the reply
# spec and does not include SSA_EXTRA_SYSTEM_TEXT. The loop still
# completes.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply_json 1 <<'JSON'
{"choices":[{"message":{"content":""}}]}
JSON

add_model_reply 2 <<'REPLY'
# complete
REPLY

MARKER='FORMAT_ERROR_OMITS_THIS'
SSA_EXTRA_SYSTEM_TEXT="$MARKER" SSA_KEEP_TEMP=1 \
    run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_has 'These are the valid reply formats:'
expect_stdout_has '# complete'
expect_stdout_lacks "$MARKER"
expect_stderr_has 'done: after 2 model prompts'

BODY=$(get_prompt_body_file 2)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
SYSTEM_FILE="$TEST_TEMP_FOLDER/systemContent.txt"
jq -j '.messages[0].content' "$BODY" >"$SYSTEM_FILE" ||
    fail "cannot read system content"
grep -qF -- "$MARKER" "$SYSTEM_FILE" ||
    fail "system prompt missing extra text"
ERROR_FILE="$TEST_TEMP_FOLDER/formatErrorTurn.txt"
jq -j '.messages[] | select(.content | startswith("Format error:"))
    | .content' "$BODY" >"$ERROR_FILE" ||
    fail "cannot read format error turn"
grep -qF -- 'These are the valid reply formats:' "$ERROR_FILE" ||
    fail "format error should reprint the reply spec"
if grep -qF -- "$MARKER" "$ERROR_FILE"; then
    fail "format error should not include extra system text"
fi
