#!/bin/sh
set -u
cd /c/Users/patri/OneDrive/Desktop/code/ssa || exit 1
TESTS_FOLDER="$(pwd)/singleFileVersion/tests"
. "$TESTS_FOLDER/testUtils.sh"
setup_test
write_script_reply "$REPLIES_FOLDER/reply1.txt" "$DONE_SENTINEL"
run_ssa --keep-temp done-test
{
    printf 'EXIT=%s\n' "$RUN_EXIT_CODE"
    printf 'STDERR:\n'
    cat "$RUN_STDERR_FILE"
    printf '\nSTDOUT:\n'
    cat "$RUN_STDOUT_FILE"
    printf '\nCASE=%s\n' "$CASE_FOLDER"
    ls -la "$CASE_BIN_FOLDER"
    printf 'jq: '
    command -v jq || printf 'missing\n'
    printf 'curl via PATH: '
    PATH="$CASE_BIN_FOLDER:$PATH" command -v curl
    printf 'reply1:\n'
    cat "$REPLIES_FOLDER/reply1.txt"
    printf '\nsessions:\n'
    find "$CASE_TMPDIR" -type f 2>/dev/null
} > /tmp/ssa-debug-out.txt 2>&1
cat /tmp/ssa-debug-out.txt
