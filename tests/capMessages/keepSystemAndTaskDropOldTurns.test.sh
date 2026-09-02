#!/bin/sh
# Several large turns past the fixed byte cap: system and task stay,
# an early unique marker is dropped from later prompt snapshots.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "a" }'
echo
echo unique-early-marker
REPLY

add_model_reply 2 <<'REPLY'
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "b" }'
echo
echo unique-second-marker
REPLY

add_model_reply 3 <<'REPLY'
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "c" }'
echo
echo unique-third-marker
REPLY

add_model_reply 4 <<'REPLY'
awk 'BEGIN { for (i = 0; i < 40000; i++) printf "d" }'
echo
echo unique-fourth-marker
REPLY

add_model_reply 5 <<'REPLY'
# task complete
REPLY

SSA_KEEP_TEMP=1 run_ssa_task print markers then stop
expect_exit 0
expect_stdout_has 'unique-early-marker'
expect_stderr_has 'done: task complete after 5 model prompts'

SNAP="$(get_kept_ssa_folder)/prompt5/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
jq -e '.[0].role == "system"' "$SNAP" >/dev/null ||
    fail "prompt5/messages.json should start with system"
jq -e '.[1].role == "user"' "$SNAP" >/dev/null ||
    fail "prompt5/messages.json[1] should be the task"
printf '%s' "$(jq -r '.[1].content' "$SNAP")" | grep -qF \
    'print markers then stop' ||
    fail "task text should remain in messages[1]"
if jq -r '.[].content' "$SNAP" | grep -qF 'unique-early-marker'
then
    fail "early marker should have been dropped from prompt5"
fi
jq -r '.[].content' "$SNAP" | grep -qF 'unique-fourth-marker' ||
    fail "latest marker should still be in prompt5"
