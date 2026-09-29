#!/bin/sh
# A missing SSA_LOG_FOLDER is a usage error. No run folder is created.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder
CALLER_TMP="$TEST_TEMP_FOLDER/callerTmp"
MISSING="$TEST_TEMP_FOLDER/no-such-log-parent"
mkdir -p "$CALLER_TMP" || fail "cannot create caller tmp"

( cd "$WORK_FOLDER" && TMPDIR="$CALLER_TMP" \
    SSA_LOG_FOLDER="$MISSING" \
    SSA_URL='http://fake.test/chat/completions' \
    SSA_MODEL=fakeModel SSA_NO_ASK=1 SSA_KEEP_TEMP=1 \
    sh "$(get_ssa_path)" a task ) \
    </dev/null \
    >"$TEST_TEMP_FOLDER/stdout.txt" 2>"$TEST_TEMP_FOLDER/stderr.txt"
SSA_EXIT_CODE=$?

expect_exit 1
expect_stderr_has 'SSA_LOG_FOLDER must be a writable directory'
if [ -e "$MISSING" ]; then fail "SSA_LOG_FOLDER path was created"; fi
set -- "$CALLER_TMP"/ssa-*
if [ -e "$1" ]; then fail "ssa folder created under TMPDIR"; fi
set -- "$TEST_TEMP_FOLDER"/ssa-*
if [ -e "$1" ]; then fail "ssa folder created under test temp"; fi
