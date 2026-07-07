# testFormatErrorsRetry.sh — parse / format errors.
#
# A reply with no ssa_script fence, one with two fences, and one with an
# empty script each append a format error and retry. A fourth, valid done
# reply then ends the run. The run keeps the session so the transcript
# can be inspected: it must hold exactly three "Format error" feedbacks.

# Write the three bad replies (no fence, two fences, empty script) plus a
# final done reply into REPLIES_FOLDER.
write_format_error_replies() {
    # no fence
    printf 'THOUGHT: no fence at all here.\n' \
        >"$REPLIES_FOLDER/reply1.txt"
    # two fences (each holds a trivial printf; the payload text is not
    # run because two blocks is itself the format error)
    printf 'THOUGHT: two.\n\n```ssa_script\nprintf a\n```\n\n%s\n' \
        '```ssa_script
printf b
```' >"$REPLIES_FOLDER/reply2.txt"
    # empty script
    printf 'THOUGHT: empty.\n\n```ssa_script\n```\n' \
        >"$REPLIES_FOLDER/reply3.txt"
    write_done_reply "$REPLIES_FOLDER/reply4.txt"
}

test_format_errors_retry() {
    write_format_error_replies
    run_ssa --keep-session format errors retry
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete after 4 model calls' || return 1
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name sessionTranscript.txt \
        2>/dev/null | head -n 1)
    [ -n "$TRANSCRIPT" ] || { fail 'no kept transcript found'; return 1; }
    COUNT=$(grep -c 'Format error' "$TRANSCRIPT")
    [ "$COUNT" = 3 ] ||
        { fail "expected 3 format errors, got $COUNT"; return 1; }
}

run_test 'parse/format errors append feedback and retry' \
    test_format_errors_retry
