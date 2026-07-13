#!/bin/sh
# testFormatErrorsRetry.sh — parse / format errors.
#
# A reply with no ssa_script fence, one with two fences, and one with an
# empty script each append a format error and retry. A fourth, valid done
# reply then ends the run. The run keeps the session so the transcript
# can be inspected: it must hold exactly three "Format error" feedbacks.

set -u
COMMUNITY_FOLDER=${COMMUNITY_FOLDER:-$(CDPATH= cd -- \
    "$(dirname "$0")/.." && pwd)}
. "$COMMUNITY_FOLDER/testUtils.sh"

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

# Write the three bad replies (no fence, two fences, empty script) plus a
# final done reply into REPLIES_FOLDER. Heredocs keep each canned reply
# readable, with the fence lines shown exactly as sent to the model.
write_format_error_replies() {
    # no fence: no ```ssa_script block at all
    cat >"$REPLIES_FOLDER/reply1.txt" <<'REPLY'
THOUGHT: no fence at all here.
REPLY
    # two fences: two blocks is itself the format error, so the payload
    # text inside them is never run
    cat >"$REPLIES_FOLDER/reply2.txt" <<'REPLY'
THOUGHT: two.

```ssa_script
printf a
```

```ssa_script
printf b
```
REPLY
    # empty script: a fenced block with no lines inside
    cat >"$REPLIES_FOLDER/reply3.txt" <<'REPLY'
THOUGHT: empty.

```ssa_script
```
REPLY
    write_script_reply "$REPLIES_FOLDER/reply4.txt" "$DONE_SENTINEL"
}

run_test 'parse/format errors append feedback and retry' \
    test_format_errors_retry

finish_if_standalone
