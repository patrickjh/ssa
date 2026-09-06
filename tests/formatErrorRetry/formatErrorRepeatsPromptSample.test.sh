#!/bin/sh
# Format error text reprints a sample from the system prompt spec,
# including # reasoning: on script/write/edit examples, not complete.

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
REASON_SCRIPT='# reasoning: look at the files in the folder'
REASON_WRITE='# reasoning: write a hello.txt file'
PREFER_WRITE='Prefer this over POSIX tools for writing files'
PREFER_EDIT='Prefer this for edits over sed'

SSA_KEEP_TEMP=1 run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_has "$SAMPLE"
expect_stdout_has '# script'
expect_stdout_has "$REASON_SCRIPT"
expect_stdout_has "$REASON_WRITE"
expect_stdout_has "$PREFER_WRITE"
expect_stdout_has "$PREFER_EDIT"
expect_stderr_has 'done: after 2 model prompts'

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
PROMPT=$(jq -r '.messages[0].content' "$BODY")
printf '%s\n' "$PROMPT" | grep -qF -- "$SAMPLE" ||
    fail "system prompt missing sample: $SAMPLE"
printf '%s\n' "$PROMPT" | grep -qF -- '# script' ||
    fail "system prompt missing # script"
printf '%s\n' "$PROMPT" | grep -qF -- "$REASON_SCRIPT" ||
    fail "system prompt missing: $REASON_SCRIPT"
printf '%s\n' "$PROMPT" | grep -qF -- "$REASON_WRITE" ||
    fail "system prompt missing: $REASON_WRITE"
printf '%s\n' "$PROMPT" | grep -qF -- "$PREFER_WRITE" ||
    fail "system prompt missing: $PREFER_WRITE"
if printf '%s\n' "$PROMPT" | grep -B2 '^# complete$' |
    grep -qF -- '# reasoning:'
then
    fail "complete example should have no reasoning line"
fi
if grep -B2 '^# complete$' "$TEST_TEMP_FOLDER/stdout.txt" |
    grep -qF -- '# reasoning:'
then
    fail "format error complete example should have no reasoning line"
fi
