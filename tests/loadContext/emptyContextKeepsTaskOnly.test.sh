#!/bin/sh
# With SSA_CONTEXT empty, the first user turn is the task only.

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

SSA_KEEP_TEMP=1 run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'

SNAP="$(get_kept_ssa_folder)/prompt1/messages.json"
[ -f "$SNAP" ] || fail "missing snapshot: $SNAP"
printf '%s' "$(jq -r '.[1].content' "$SNAP")" | grep -qF \
    'print a greeting then stop' ||
    fail "task text should be in messages[1]"
if printf '%s' "$(jq -r '.[1].content' "$SNAP")" | grep -qF 'Context:'
then
    fail "empty SSA_CONTEXT should not add a Context: block"
fi
