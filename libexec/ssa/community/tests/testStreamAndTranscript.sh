# testStreamAndTranscript.sh — script output is streamed to stdout and
# appears in the transcript when run with --keep-session. Also proves the
# configured script runner (SSA_SCRIPT_RUNNER) is on the path by checking
# for its marker. This test sets its own SSA_SCRIPT_RUNNER, so it does not
# use run_ssa.

test_stream_and_transcript() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" \
        'printf streamed-marker-line\n'
    write_done_reply "$REPLIES_FOLDER/reply2.txt"
    env TMPDIR="$CASE_TMPDIR" \
        SSA_STUB_REPLIES_FOLDER="$REPLIES_FOLDER" \
        SSA_MODEL_RUNNER="$STUB_MODEL_RUNNER" \
        SSA_SCRIPT_RUNNER="$STUB_SCRIPT_RUNNER" \
        SSA_MODEL="stubModel" SSA_MODEL_CALLS=0 \
        sh "$SSA_SCRIPT" --keep-session stream to stdout </dev/null \
        >"$RUN_STDOUT_FILE" 2>"$RUN_STDERR_FILE"
    RUN_EXIT_CODE=$?
    expect_exit 0 || return 1
    # Streamed live to stdout.
    expect_stdout_has 'streamed-marker-line' || return 1
    # Script runner path was used.
    expect_stdout_has 'STUB_SCRIPT_RUNNER_RAN' || return 1
    # And recorded in the kept transcript.
    expect_transcript_has 'streamed-marker-line' || return 1
}

run_test 'script output streamed and in transcript' \
    test_stream_and_transcript
