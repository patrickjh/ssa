#!/bin/sh
# SSA_NO_EDITS=1 turns # edit file: into a format error. The file
# is unchanged, ask does not run, and a later # complete still works.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

printf '%s\n' 'keep-me' >"$WORK_FOLDER/notes.txt" ||
    fail "cannot write starting file"

add_model_reply 1 <<'REPLY'
# edit file: notes.txt
<<<<<<< SEARCH
keep-me
=======
changed
>>>>>>> REPLACE
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

printf '%s\n' 'keep-me' >"$TEST_TEMP_FOLDER/expected.txt" ||
    fail "cannot write expected file"

SSA_KEEP_TEMP=1 SSA_NO_EDITS=1 \
    run_ssa_task edit notes.txt then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_lacks 'edited file:'
expect_stdout_lacks 'edit failed:'
expect_stdout_lacks '# edit file: hello.txt'
expect_stdout_lacks 'Prefer this for edits over sed'
expect_stderr_has 'done: after 2 model prompts'
expect_file_equals "$WORK_FOLDER/notes.txt" \
    "$TEST_TEMP_FOLDER/expected.txt"

BODY=$(get_prompt_body_file 1)
[ -f "$BODY" ] || fail "missing body.json: $BODY"
PROMPT=$(jq -r '.messages[0].content' "$BODY")
printf '%s\n' "$PROMPT" | grep -qF -- '# script' ||
    fail "system prompt missing # script"
if printf '%s\n' "$PROMPT" | grep -qF -- '# edit file:'
then
    fail "no-edit run should omit # edit file: from the prompt"
fi
if printf '%s\n' "$PROMPT" | grep -qF -- 'SSA_NO_EDITS'
then
    fail "format spec should not name SSA_NO_EDITS"
fi
if printf '%s\n' "$PROMPT" | grep -qF -- '# write file:'
then
    :
else
    fail "writes should still be in the prompt when only edits are off"
fi
