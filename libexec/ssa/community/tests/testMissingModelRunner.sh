# testMissingModelRunner.sh — missing model runner fails at startup via
# util_die with exit 1. This test does not use run_ssa because it must
# run the harness with SSA_MODEL_RUNNER unset.

test_missing_model_runner() {
    write_done_reply "$REPLIES_FOLDER/reply1.txt"
    env TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 SSA_KEEP_SESSION=0 \
        sh "$SSA_SCRIPT" no runner set here </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 1 || return 1
    expect_stderr_has 'model runner not set' || return 1
}

run_test 'missing model runner fails at startup' \
    test_missing_model_runner
