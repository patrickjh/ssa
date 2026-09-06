#!/bin/sh
# Harness smoke for experiments/interpreter/ssa. Not part of
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
    CASE_FAIL=$FAIL
    RAN=$((RAN + 1))
    TMP="${TMPDIR:-/tmp}/interpreterTry.$$.$RAN"
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

ok_if_clean() {
    [ "$FAIL" -eq "$CASE_FAIL" ] && pass
}

# --- cases ---

setup_case show_help
sh "$SSA" -h >"$STDOUT" 2>"$STDERR"
[ "$?" = 0 ] || fail "exit $?"
need 'SSA_INTERPRETER' "$STDOUT"
need_not 'SSA_RUNNER' "$STDOUT"
ok_if_clean

setup_case default_sh
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# script
printf 'hello-from-script\n'
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork print a greeting then stop
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'hello-from-script' "$STDOUT"
need_not 'PYTHON3_STUB' "$STDOUT"
need 'done: after 2 model prompts' "$STDERR"
ok_if_clean

setup_case notes_not_on_stdin
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# AAA_NOTE
# script
print("payload-only")
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=python3 run_fork notes then script
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'print("payload-only")' "$STDOUT"
need_not '# AAA_NOTE' "$STDOUT"
need_not '# script' "$STDOUT"
ok_if_clean

setup_case python3_stub
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# script
print("hello-from-python")
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=python3 run_fork run python then stop
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'PYTHON3_STUB' "$STDOUT"
need 'print("hello-from-python")' "$STDOUT"
need_not '# script' "$STDOUT"
ok_if_clean

setup_case python_payload_not_sh
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# script
print(1)
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=python3 run_fork python is not valid sh
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'PYTHON3_STUB' "$STDOUT"
need 'print(1)' "$STDOUT"
need_not 'Format error:' "$STDOUT"
ok_if_clean

setup_case empty_script_payload
add_reply 1 <<'REPLY'
# script
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
run_fork empty script payload
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'Format error:' "$STDOUT"
ok_if_clean

setup_case slash_in_SSA_INTERPRETER
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=/bin/sh run_fork path token
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'SSA_INTERPRETER cannot contain /' "$STDERR"
ok_if_clean

setup_case empty_SSA_INTERPRETER
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER= run_fork empty interpreter
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'SSA_INTERPRETER is empty' "$STDERR"
ok_if_clean

setup_case two_words
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER='sh python3' run_fork two words
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'SSA_INTERPRETER must be one PATH name' "$STDERR"
ok_if_clean

setup_case missing_interpreter
add_reply 1 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=noSuchInterp12345 run_fork missing interpreter
[ "$EXIT_CODE" = 1 ] || fail "exit $EXIT_CODE"
need 'interpreter not found: noSuchInterp12345' "$STDERR"
need 'SSA_INTERPRETER' "$STDERR"
ok_if_clean

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
ok_if_clean

setup_case write_with_python3
write_stub python3 PYTHON3_STUB
add_reply 1 <<'REPLY'
# write file: via-sh.txt
only-sh
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_INTERPRETER=python3 run_fork write with python interpreter
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'wrote file: via-sh.txt' "$STDOUT"
need_not 'PYTHON3_STUB' "$STDOUT"
[ -f "$WORK/via-sh.txt" ] || fail "via-sh.txt missing"
ok_if_clean

setup_case sandbox_not_on_scripts
SANDBOX_STUB="$TMP/sandboxHit"
cat >"$SANDBOX_STUB" <<'STUB' || exit 1
#!/bin/sh
printf 'SANDBOX_HIT\n'
exit 1
STUB
chmod +x "$SANDBOX_STUB" || exit 1
add_reply 1 <<'REPLY'
# script
printf 'not-sandboxed\n'
REPLY
add_reply 2 <<'REPLY'
# complete
REPLY
SSA_SANDBOX_COMMAND="$SANDBOX_STUB" run_fork ignore sandbox on scripts
[ "$EXIT_CODE" = 0 ] || fail "exit $EXIT_CODE"
need 'not-sandboxed' "$STDOUT"
need_not 'SANDBOX_HIT' "$STDOUT"
ok_if_clean

printf '\n%s ran, %s failed\n' "$RAN" "$FAIL"
[ "$FAIL" = 0 ]
