#!/bin/sh
# SSA_NO_WRITES=1 turns # write file: into a format error. No file
# is created, ask does not run, and a later # complete still works.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
# write file: notes.txt
should-not-land
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

SSA_KEEP_TEMP=1 SSA_NO_WRITES=1 \
    run_ssa_task write notes.txt then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_lacks 'wrote file:'
expect_stdout_lacks '# write file: hello.txt'
expect_stdout_lacks 'Prefer this over POSIX tools for writing files'
expect_stderr_has 'done: after 2 model prompts'
expect_no_file "$WORK_FOLDER/notes.txt"

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
PROMPT=$(jq -r '.messages[0].content' "$BODY")
printf '%s\n' "$PROMPT" | grep -qF -- '# script' ||
    fail "system prompt missing # script"
if printf '%s\n' "$PROMPT" | grep -qF -- '# write file:'
then
    fail "no-write run should omit # write file: from the prompt"
fi
if printf '%s\n' "$PROMPT" | grep -qF -- 'SSA_NO_WRITES'
then
    fail "format spec should not name SSA_NO_WRITES"
fi
if printf '%s\n' "$PROMPT" | grep -qF -- '# edit file:'
then
    :
else
    fail "edits should still be in the prompt when only writes are off"
fi
