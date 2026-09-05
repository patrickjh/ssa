#!/bin/sh
# Harness smoke for experiments/runSentinel/ssa. Not part of
# tests/runTests.sh. Fake curl, SSA_NO_ASK=1.
set -u

HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd) || exit 1
SSA="$HERE/ssa"
FAIL=0
RAN=0

fail() {
    printf 'FAIL %s: %s\n' "$CASE" "$1" >&2
    FAIL=$((FAIL + 1))
}

pass() {
    printf 'ok %s\n' "$CASE"
}

need() {
    grep -qF -- "$1" "$2" || fail "missing in $(basename "$2"): $1"
}

need_not() {
    if grep -qF -- "$1" "$2"; then
        fail "should not contain in $(basename "$2"): $1"
    fi
}

setup_case() {
    CASE=$1
    RAN=$((RAN + 1))
    TMP="${TMPDIR:-/tmp}/runSentinelTry.$$.$RAN"
    mkdir "$TMP" || exit 1
    REPLIES="$TMP/replies"
    FAKE="$TMP/fakeCommands"
    WORK="$TMP/work"
    mkdir "$REPLIES" "$FAKE" "$WORK" || exit 1
    write_fake_curl
    PATH="$FAKE:$PATH"
    export PATH
    SSA_TEST_REPLIES_FOLDER="$REPLIES"
    export SSA_TEST_REPLIES_FOLDER
    STDOUT="$TMP/stdout.txt"
    STDERR="$TMP/stderr.txt"
}

write_fake_curl() {
    cat >"$FAKE/curl" <<'FAKE_CURL' || exit 1
#!/bin/sh
set -u
COUNT_FILE="$SSA_TEST_REPLIES_FOLDER/curlCount.txt"
COUNT=0
if [ -f "$COUNT_FILE" ]; then COUNT=$(cat "$COUNT_FILE"); fi
COUNT=$((COUNT + 1))
printf '%s\n' "$COUNT" >"$COUNT_FILE" || exit 1
REPLY_FILE="$SSA_TEST_REPLIES_FOLDER/reply${COUNT}.txt"
[ -f "$REPLY_FILE" ] || {
    printf 'fake curl: no canned reply: %s\n' "$REPLY_FILE" >&2
    exit 1
}
OUT_FILE=""
PREV=""
for ARG in "$@"; do
    if [ "$PREV" = "-o" ]; then OUT_FILE=$ARG; fi
    PREV=$ARG
done
[ -n "$OUT_FILE" ] || exit 1
cp "$REPLY_FILE" "$OUT_FILE" || exit 1
exit 0
FAKE_CURL
    chmod +x "$FAKE/curl" || exit 1
}

add_reply() {
    jq -Rs '{choices: [{message: {content: .}}]}' \
        >"$REPLIES/reply$1.txt" || exit 1
}

add_review() {
    N=1
    while [ -f "$REPLIES/reply$N.txt" ]; do
        N=$((N + 1))
    done
    printf '%s\n' 'canned review' | add_reply "$N"
}

run_fork() {
    add_review
    (
        cd "$WORK" &&
            TMPDIR="$TMP" \
            SSA_URL='http://fake.test/chat/completions' \
            SSA_MODEL=fakeModel \
            SSA_NO_ASK=1 \
            SSA_KEEP_TEMP=1 \
            sh "$SSA" "$@"
    ) </dev/null >"$STDOUT" 2>"$STDERR"
    EXIT_CODE=$?
}

write_stub() {
    # $1 = name on PATH, $2 = marker printed, then cat stdin
    cat >"$FAKE/$1" <<STUB || exit 1
#!/bin/sh
printf '%s\n' '$2'
cat
STUB
    chmod +x "$FAKE/$1" || exit 1
}

# --- cases ---

setup_case run_sh
add_reply 1 <<'REPLY'
# run sh
printf 'hello-from-script\n'
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork print a greeting then stop
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'hello-from-script' "$STDOUT"
need 'done: after 2 model prompts' "$STDERR"
[ "$FAIL" -eq 0 ] && pass

setup_case notes_not_on_stdin
add_reply 1 <<'REPLY'
# AAA_NOTE
# run sh
sed -n '$='
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork notes then run
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
grep -qE '^ *[1]$' "$STDOUT" || fail "expected stdin line count 1"
if grep -qE '^ *[3]$' "$STDOUT"; then
    fail "notes leaked (stdin line count 3)"
fi
[ "$FAIL" -eq 0 ] && pass

setup_case run_python3_stub
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# run python3
print("hello-from-python")
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_RUNNER="sh python3" run_fork run python then stop
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'PYTHON3_STUB' "$STDOUT"
need 'print("hello-from-python")' "$STDOUT"
[ "$FAIL" -eq 0 ] && pass

setup_case unknown_ruby
add_reply 1 <<'REPLY'
# run ruby
puts "nope"
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork unknown runner
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'Format error: use exactly one of:' "$STDOUT"
[ "$FAIL" -eq 0 ] && pass

setup_case slash_run_name
add_reply 1 <<'REPLY'
# run /usr/bin/python3
print(1)
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork slash in run name
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'Format error: use exactly one of:' "$STDOUT"
[ "$FAIL" -eq 0 ] && pass

setup_case missing_runner_startup
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_RUNNER=noSuchRunner12345 run_fork missing runner
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'runner not found: noSuchRunner12345' "$STDERR"
[ "$FAIL" -eq 0 ] && pass

setup_case slash_in_SSA_RUNNER
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_RUNNER=/bin/sh run_fork path token
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'SSA_RUNNER names cannot contain /' "$STDERR"
[ "$FAIL" -eq 0 ] && pass

setup_case write_with_sh
add_reply 1 <<'REPLY'
# write file: hello.txt
hello
world
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork write a file
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'wrote file: hello.txt' "$STDOUT"
[ -f "$WORK/hello.txt" ] || fail "hello.txt missing"
grep -qF hello "$WORK/hello.txt" || fail "hello.txt contents"
[ "$FAIL" -eq 0 ] && pass

setup_case write_uses_sh_not_python
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# write file: via-sh.txt
only-sh
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_RUNNER="sh python3" run_fork write with python listed
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'wrote file: via-sh.txt' "$STDOUT"
need_not 'PYTHON3_STUB' "$STDOUT"
[ "$FAIL" -eq 0 ] && pass

setup_case write_fails_without_sh
write_stub python3 PYTHON3_STUB
printf 'keep-me\n' >"$WORK/stay.txt"
add_reply 1 <<'REPLY'
# write file: stay.txt
should-not-write
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_RUNNER=python3 run_fork write without sh
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'write failed: sh not in SSA_RUNNER' "$STDOUT"
grep -qF keep-me "$WORK/stay.txt" || fail "stay.txt was changed"
need_not 'should-not-write' "$WORK/stay.txt"
[ "$FAIL" -eq 0 ] && pass

setup_case jail_sh_does_not_write
write_stub jail-sh JAIL_SH
add_reply 1 <<'REPLY'
# write file: jailed.txt
nope
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_RUNNER=jail-sh run_fork jail-sh is not sh
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'write failed: sh not in SSA_RUNNER' "$STDOUT"
[ ! -f "$WORK/jailed.txt" ] || fail "jailed.txt should not exist"
[ "$FAIL" -eq 0 ] && pass

setup_case sandbox_env_ignored
SANDBOX_STUB="$TMP/sandboxHit"
cat >"$SANDBOX_STUB" <<'STUB' || exit 1
#!/bin/sh
printf 'SANDBOX_HIT\n'
exit 1
STUB
chmod +x "$SANDBOX_STUB" || exit 1
add_reply 1 <<'REPLY'
# run sh
printf 'not-sandboxed\n'
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_SANDBOX_COMMAND="$SANDBOX_STUB" run_fork ignore sandbox env
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'not-sandboxed' "$STDOUT"
need_not 'SANDBOX_HIT' "$STDOUT"
[ "$FAIL" -eq 0 ] && pass

printf '\n%s ran, %s failed\n' "$RAN" "$FAIL"
[ "$FAIL" = 0 ]
