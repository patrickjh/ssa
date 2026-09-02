#!/bin/sh
# SSA_CONTEXT file bytes follow the task after a Context: delimiter.
# A copy is kept as context.txt when SSA_KEEP_TEMP=1.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'repo notes for the model' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write context file"

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

SSA_CONTEXT=notes.txt SSA_KEEP_TEMP=1 \
    run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'

SNAP="$(get_kept_ssa_folder)/prompt1/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
USER_TURN=$(jq -j '.[1].content' "$SNAP")
printf '%s' "$USER_TURN" | grep -qF 'print a greeting then stop' ||
    fail "task text should be in messages[1]"
printf '%s' "$USER_TURN" | grep -qF 'Context:' ||
    fail "messages[1] should contain Context:"
printf '%s' "$USER_TURN" | grep -qF 'repo notes for the model' ||
    fail "context file bytes should be in messages[1]"

CTX="$(get_kept_ssa_folder)/context.txt"
[ -f "$CTX" ] || fail "missing context.txt log"
expect_file_equals "$CTX" "$WORK_FOLDER/notes.txt"
