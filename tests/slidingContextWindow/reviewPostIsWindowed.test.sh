#!/bin/sh
# The review POST uses the same window as model prompts.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 4000; i++) printf "a" }'
echo
echo unique-early-marker
REPLY

add_model_reply 2 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 4000; i++) printf "b" }'
echo
echo unique-second-marker
REPLY

add_model_reply 3 <<'REPLY'
# complete
REPLY

SSA_MAX_CONTEXT_BYTES=1000 SSA_KEEP_TEMP=1 \
    run_ssa_task print markers then stop
expect_exit 0
expect_stderr_has 'Feedback from model:'

BODY=$(get_prompt_body_file 4)
[ -f "$BODY" ] || fail "missing review body.json: $BODY"
jq -e '[.messages[].role] == ["system","user","assistant","user"]' \
    "$BODY" >/dev/null ||
    fail "review body roles should still alternate"
printf '%s' "$(jq -r '.messages[1].content' "$BODY")" | grep -qF \
    'print markers then stop' ||
    fail "review body should keep the task"
jq -r '.messages[].content' "$BODY" | grep -qF \
    'what would have made this run go better' ||
    fail "review body should keep the review ask"
if jq -r '.messages[].content' "$BODY" | grep -qF 'unique-early-marker'
then
    fail "review body should drop the early marker"
fi

SNAP="$(get_kept_ssa_folder)/prompt4/messages.json"
[ -f "$SNAP" ] || fail "missing review snapshot: $SNAP"
jq -r '.[].content' "$SNAP" | grep -qF 'unique-early-marker' ||
    fail "review messages.json should still have the early marker"
