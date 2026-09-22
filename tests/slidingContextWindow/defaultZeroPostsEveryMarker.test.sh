#!/bin/sh
# Default SSA_MAX_CONTEXT_BYTES=0 posts every large turn.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "a" }'
echo
echo unique-early-marker
REPLY

add_model_reply 2 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "b" }'
echo
echo unique-second-marker
REPLY

add_model_reply 3 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "c" }'
echo
echo unique-third-marker
REPLY

add_model_reply 4 <<'REPLY'
# script
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "d" }'
echo
echo unique-fourth-marker
REPLY

add_model_reply 5 <<'REPLY'
# complete
REPLY

unset SSA_MAX_CONTEXT_BYTES
SSA_KEEP_TEMP=1 run_ssa_task print markers then stop
expect_exit 0
expect_stderr_has 'done: after 5 model prompts'

BODY=$(get_prompt_body_file 5)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
jq -e '.messages | length == 12' "$BODY" >/dev/null ||
    fail "budget 0 should post every turn"
jq -e '.messages[0].role == "system"' "$BODY" >/dev/null ||
    fail "messages[0] should be system"
jq -e '.messages[1].role == "user"' "$BODY" >/dev/null ||
    fail "messages[1] should be the task"
printf '%s' "$(jq -r '.messages[1].content' "$BODY")" | grep -qF \
    'print markers then stop' ||
    fail "task text should remain in messages[1]"
for MARKER in unique-early-marker unique-second-marker \
    unique-third-marker unique-fourth-marker
do
    jq -e --arg marker "$MARKER" \
        'any(.messages[]; .content | contains($marker))' \
        "$BODY" >/dev/null ||
        fail "body should still contain $MARKER"
done
