#!/bin/sh
# stubModelRunner.sh — offline model runner for the sanity tests.
# Replays one canned model reply per model call, so the test suite runs
# with no network and no llama.cpp. Set SSA_MODEL_RUNNER to this file.
#
# Contract (same as any ssa model runner):
#   stdin      full prompt text (ignored here; replies are canned)
#   stdout     the canned model reply for this call
#   exit code  0 on success; non-zero to make ssa retry the same prompt
#
# Which reply to send:
#   Reads the file named reply$SSA_MODEL_CALLS.txt from the folder in
#   SSA_STUB_REPLIES_FOLDER (call 1 -> reply1.txt, call 2 -> reply2.txt).
#   ssa exports SSA_MODEL_CALLS and bumps it each loop iteration.
#   A reply file whose first line is the word RUNNER_FAIL makes this
#   runner exit non-zero (to drive the runner-retry path) after dropping
#   that marker line, so the rest of the file is unused.

set -u

[ -n "${SSA_STUB_REPLIES_FOLDER:-}" ] || {
    printf 'stubModelRunner: SSA_STUB_REPLIES_FOLDER not set\n' >&2
    exit 1
}
[ -n "${SSA_MODEL_CALLS:-}" ] || {
    printf 'stubModelRunner: SSA_MODEL_CALLS not set; run via ssa\n' >&2
    exit 1
}

cat >/dev/null  # drain the prompt on stdin; replies are canned

REPLY_FILE="${SSA_STUB_REPLIES_FOLDER}/reply${SSA_MODEL_CALLS}.txt"
[ -f "$REPLY_FILE" ] || {
    printf 'stubModelRunner: no canned reply: %s\n' "$REPLY_FILE" >&2
    exit 1
}

FIRST_LINE=$(head -n 1 "$REPLY_FILE")
if [ "$FIRST_LINE" = "RUNNER_FAIL" ]; then
    exit 1
fi

cat "$REPLY_FILE"
