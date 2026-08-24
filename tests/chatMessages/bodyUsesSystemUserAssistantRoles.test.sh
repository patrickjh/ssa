#!/bin/sh
# prompt1/body.json is system + user(task) + assistant(bootstrap) +
# user(script result), not one user message.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task --keep-temp print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
jq -e '.messages[0].role == "system"' "$BODY" >/dev/null ||
    fail "messages[0] should be system"
jq -e '.messages[1].role == "user"' "$BODY" >/dev/null ||
    fail "messages[1] should be user"
jq -e '.messages[2].role == "assistant"' "$BODY" >/dev/null ||
    fail "messages[2] should be assistant"
jq -e '.messages[3].role == "user"' "$BODY" >/dev/null ||
    fail "messages[3] should be user"
jq -e '.messages | length >= 4' "$BODY" >/dev/null ||
    fail "expected at least 4 messages"
printf '%s' "$(jq -r '.messages[1].content' "$BODY")" | grep -qF \
    'print a greeting then stop' ||
    fail "user message should be the task"
jq -r '.messages[2].content' "$BODY" | grep -qF \
    'echo starting the agent' ||
    fail "assistant message should be the bootstrap script"
[ -f "$(get_kept_ssa_folder)/prompt1/response.txt" ] ||
    fail "missing prompt1/response.txt"

MESSAGES_SNAP="$(get_kept_ssa_folder)/prompt1/messages.json"
[ -f "$MESSAGES_SNAP" ] || fail "missing prompt snapshot: $MESSAGES_SNAP"
jq -e '.[0].role == "system"' "$MESSAGES_SNAP" >/dev/null ||
    fail "prompt1/messages.json should be a messages array"
expect_no_file "$(get_kept_ssa_folder)/fullTranscript.txt"
expect_no_file "$(get_kept_ssa_folder)/prompt1/transcript.txt"
