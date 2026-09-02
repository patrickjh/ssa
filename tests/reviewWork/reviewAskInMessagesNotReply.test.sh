#!/bin/sh
# Review curl is promptN+1. messages.json has the review ask, not
# the review reply.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

add_model_reply 3 <<'REPLY'
use a write request next time
REPLY

SSA_KEEP_TEMP=1 run_ssa_task print a greeting then stop
expect_exit 0

REVIEW_BODY=$(get_prompt_body_file 3)
[ -f "$REVIEW_BODY" ] || fail "missing review body.json: $REVIEW_BODY"
MESSAGES="$(get_kept_ssa_folder)/messages.json"
[ -f "$MESSAGES" ] || fail "missing messages.json"
jq -e '.[-1].role == "user"' "$MESSAGES" >/dev/null ||
    fail "last turn should be the review ask"
printf '%s' "$(jq -r '.[-1].content' "$MESSAGES")" | grep -qF \
    'what would have made this run go better' ||
    fail "last turn should ask what would have made this run go better"
if jq -r '.[].content' "$MESSAGES" | grep -qF \
    'use a write request next time'
then
    fail "review reply should not be a chat turn"
fi
