#!/bin/sh
# Context larger than the old 131072-byte cap still loads; the
# first user turn is POSTed as-is.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

awk 'BEGIN { for (i = 0; i < 140000; i++) printf "x" }' \
    >"$WORK_FOLDER/huge-context.txt" ||
    fail "cannot write huge context file"

add_model_reply 1 <<'REPLY'
# complete
REPLY

SSA_CONTEXT=huge-context.txt SSA_KEEP_TEMP=1 \
    run_ssa_task a task
expect_exit 0
expect_stderr_has 'done: after 1 model prompts'

SNAP="$(get_kept_ssa_folder)/prompt1/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
LEN=$(jq -r '.[1].content | length' "$SNAP" | tr -d '\r')
[ "$LEN" -gt 131072 ] ||
    fail "first user turn should still hold the huge context"
