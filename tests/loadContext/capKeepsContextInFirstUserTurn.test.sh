#!/bin/sh
# After later turns are dropped, the first user turn still has context.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'unique-context-marker' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write context file"

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

SSA_CONTEXT=notes.txt SSA_KEEP_TEMP=1 \
    run_ssa_task print markers then stop
expect_exit 0
expect_stderr_has 'done: task complete after 5 model prompts'

SNAP="$(get_kept_ssa_folder)/prompt5/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
printf '%s' "$(jq -r '.[1].content' "$SNAP")" | grep -qF \
    'unique-context-marker' ||
    fail "context should remain in messages[1] after capping"
if jq -r '.[].content' "$SNAP" | grep -qF 'unique-early-marker'
then
    fail "early marker should have been dropped from prompt5"
fi
