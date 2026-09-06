#!/bin/sh
# Format error text reprints a sample from the system prompt spec.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply_json 1 <<'JSON'
{"choices":[{"message":{"content":""}}]}
JSON

add_model_reply 2 <<'REPLY'
# complete
REPLY

SAMPLE='# write file: hello.txt'

SSA_KEEP_TEMP=1 run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_has "$SAMPLE"
expect_stderr_has 'done: after 2 model prompts'

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
jq -r '.messages[0].content' "$BODY" | grep -qF -- "$SAMPLE" ||
    fail "system prompt missing sample: $SAMPLE"
