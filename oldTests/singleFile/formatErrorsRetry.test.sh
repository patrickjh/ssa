#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_format_errors_retry() {
    write_format_error_replies
    run_ssa --keep-temp format errors retry
    expect_exit 0 || return 1
    expect_stderr_has 'done: task complete after 4 model prompts' ||
        return 1
    TRANSCRIPT=$(find "$CASE_TMPDIR" -name fullTranscript.txt \
        2>/dev/null | sed -n '1p')
    [ -n "$TRANSCRIPT" ] || { fail 'no kept transcript found'; return 1; }
    COUNT=$(grep -c 'Format error' "$TRANSCRIPT")
    [ "$COUNT" = 3 ] ||
        { fail "expected 3 format errors, got $COUNT"; return 1; }
}

write_format_error_replies() {
    cat >"$REPLIES_FOLDER/reply1.txt" <<'REPLY'
THOUGHT: no fence at all here.
REPLY
    cat >"$REPLIES_FOLDER/reply2.txt" <<'REPLY'
THOUGHT: two.

```ssa_script
printf a
```

```ssa_script
printf b
```
REPLY
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
