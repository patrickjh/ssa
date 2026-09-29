#!/bin/sh
# A set SSA_LOG_FOLDER holds the run folder. Scripts still see TMPDIR.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder
CALLER_TMP="$TEST_TEMP_FOLDER/callerTmp"
LOG_PARENT="$TEST_TEMP_FOLDER/logParent"
mkdir -p "$CALLER_TMP" "$LOG_PARENT" || fail "cannot create parents"

add_model_reply 1 <<'REPLY'
# script
printf '%s\n' "$TMPDIR"
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

add_default_review_reply
( cd "$WORK_FOLDER" && TMPDIR="$CALLER_TMP" \
    SSA_LOG_FOLDER="$LOG_PARENT" \
    SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel SSA_NO_ASK=1 SSA_KEEP_TEMP=1 \
    sh "$(get_ssa_path)" print tmpdir then stop ) \
    </dev/null \
    >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
SSA_EXIT_CODE=$?

expect_exit 0
expect_stderr_has 'done: after 2 model prompts'
expect_stdout_has "$CALLER_TMP"
expect_stdout_lacks "$LOG_PARENT"
set -- "$LOG_PARENT"/ssa-*
[ -d "$1" ] || fail "no ssa folder under SSA_LOG_FOLDER"
[ "$#" -eq 1 ] || fail "expected one ssa folder, got $#"
[ -f "$1/messages.json" ] || fail "run folder has no messages.json"
set -- "$CALLER_TMP"/ssa-*
if [ -e "$1" ]; then fail "ssa folder created under TMPDIR"; fi
