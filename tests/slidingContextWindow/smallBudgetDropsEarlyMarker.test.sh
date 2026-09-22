#!/bin/sh
# A budget below one fat turn keeps the task and the newest pair.
# The early marker leaves body.json and stays in messages.json.

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
# script
awk 'BEGIN { for (i = 0; i < 4000; i++) printf "c" }'
echo
echo unique-third-marker
REPLY

add_model_reply 4 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 4000; i++) printf "d" }'
echo
echo unique-fourth-marker
REPLY

add_model_reply 5 <<'REPLY'
# complete
REPLY

SSA_MAX_CONTEXT_BYTES=1000 SSA_KEEP_TEMP=1 \
    run_ssa_task print markers then stop
expect_exit 0
expect_stderr_has 'done: after 5 model prompts'

BODY=$(get_prompt_body_file 5)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
jq -e '[.messages[].role] == ["system","user","assistant","user"]' \
    "$BODY" >/dev/null ||
    fail "body should be system, task, newest assistant, newest user"
printf '%s' "$(jq -r '.messages[1].content' "$BODY")" | grep -qF \
    'print markers then stop' ||
    fail "task text should stay in the pinned user turn"
jq -r '.messages[].content' "$BODY" | grep -qF 'unique-fourth-marker' ||
    fail "latest result should stay in body.json"
if jq -r '.messages[].content' "$BODY" | grep -qF 'unique-early-marker'
then
    fail "early marker should be dropped from body.json"
fi

SNAP="$(get_kept_ssa_folder)/prompt5/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
jq -r '.[].content' "$SNAP" | grep -qF 'unique-early-marker' ||
    fail "early marker should still be in prompt5/messages.json"
jq -e --slurpfile body "$BODY" \
    'length > ($body[0].messages | length)' "$SNAP" >/dev/null ||
    fail "messages.json should keep turns the body dropped"
