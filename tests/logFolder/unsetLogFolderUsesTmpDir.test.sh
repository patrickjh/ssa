#!/bin/sh
# Unset SSA_LOG_FOLDER: the run folder is created under TMPDIR.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder
CALLER_TMP="$TEST_TEMP_FOLDER/callerTmp"
LOG_PARENT="$TEST_TEMP_FOLDER/logParent"
mkdir -p "$CALLER_TMP" "$LOG_PARENT" || fail "cannot create parents"

add_model_reply 1 <<'REPLY'
# complete
REPLY

add_default_review_reply
( unset SSA_LOG_FOLDER
  cd "$WORK_FOLDER" && TMPDIR="$CALLER_TMP" \
    SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel SSA_NO_ASK=1 SSA_KEEP_TEMP=1 \
    sh "$(get_ssa_path)" print a greeting then stop ) \
    </dev/null \
    >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
SSA_EXIT_CODE=$?

expect_exit 0
expect_stderr_has 'done: after 1 model prompts'
set -- "$CALLER_TMP"/ssa-*
[ -d "$1" ] || fail "no ssa folder under TMPDIR"
[ "$#" -eq 1 ] || fail "expected one ssa folder under TMPDIR, got $#"
set -- "$LOG_PARENT"/ssa-*
if [ -e "$1" ]; then fail "ssa folder under the other parent"; fi
