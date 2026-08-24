#!/bin/sh
# Extra JSON fields land in body.json; ssa model and messages win if
# the object also sets those keys.

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

run_ssa_task --keep-temp \
    --request-json '{"think":false,"max_tokens":8192,"model":"fromExtra"}' \
    print a greeting then stop
expect_exit 0
expect_stdout_has 'hello-from-script'

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
jq -e '.think == false' "$BODY" >/dev/null || fail "missing think"
jq -e '.max_tokens == 8192' "$BODY" >/dev/null || fail "missing max_tokens"
jq -e '.model == "fakeModel"' "$BODY" >/dev/null ||
    fail "ssa model should win over extra JSON"
jq -e '.messages[0].role == "system"' "$BODY" >/dev/null ||
    fail "messages should still be present"
