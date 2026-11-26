#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/ssa-test.XXXXXX") || exit 1
trap 'find "$TMP" -depth -delete 2>/dev/null || rm -rf "$TMP"' 0 1 2 3 15

mkdir "$TMP/bin" "$TMP/logs"
cat >"$TMP/bin/curl" <<'EOF'
#!/bin/sh
jq -n --arg content "$MOCK_REPLY" \
    '{choices:[{message:{content:$content}}]}'
EOF
chmod +x "$TMP/bin/curl"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_ssa() {
    MOCK_REPLY=$1
    shift
    (
        export MOCK_REPLY
        export SSA_URL="https://example.invalid/chat"
        export SSA_MODEL="test-model"
        export SSA_LOGS="$TMP/logs"
        export SSA_YES=1
        export PATH="$TMP/bin:$PATH"
        "$ROOT/ssa" "$@"
    )
}

run_ssa 'ls' --tools 'allow:ls' -y 'list files' >/dev/null 2>&1 ||
    fail "allowed command"

if run_ssa 'rm -rf /tmp/ssa-should-not-run' \
    --tools 'allow:ls,cat,grep,find' -y 'remove file' \
    >/dev/null 2>"$TMP/blocked.err"
then
    fail "blocked allowlist command"
fi
grep -q 'blocked command: rm' "$TMP/blocked.err" ||
    fail "blocked command was not reported"

if run_ssa 'ls | rm -rf /tmp/ssa-should-not-run' \
    --tools 'allow:ls,cat,grep,find' -y 'pipeline' \
    >/dev/null 2>"$TMP/pipeline.err"
then
    fail "pipeline with blocked command"
fi
grep -q 'blocked command: rm' "$TMP/pipeline.err" ||
    fail "pipeline violation was not reported"

if run_ssa 'printf "%s\n" "$(rm -rf /tmp/ssa-should-not-run)"' \
    --tools 'deny:rm' -y 'substitution' \
    >/dev/null 2>"$TMP/substitution.err"
then
    fail "command substitution"
fi
grep -q 'shell' "$TMP/substitution.err" ||
    fail "command substitution violation was not reported"

if run_ssa 'cd /tmp' --tools 'allow:ls' -y 'change directory' \
    >/dev/null 2>"$TMP/builtin.err"
then
    fail "shell builtin allowlist"
fi
grep -q 'blocked command: cd' "$TMP/builtin.err" ||
    fail "shell builtin violation was not reported"

if run_ssa 'ls' --tools 'allow:' -y 'malformed allow policy' \
    >/dev/null 2>"$TMP/malformed.err"
then
    fail "malformed policy"
fi
grep -q 'invalid SSA_TOOLS policy' "$TMP/malformed.err" ||
    fail "malformed policy was not rejected"

if SSA_TOOLS='deny:rm' run_ssa 'rm -rf /tmp/ssa-should-not-run' \
    --tools 'allow:ls' -y 'CLI precedence' \
    >/dev/null 2>"$TMP/precedence.err"
then
    fail "CLI policy did not override environment"
fi
grep -q 'blocked command: rm' "$TMP/precedence.err" ||
    fail "CLI precedence violation was not reported"

if run_ssa 'rm -rf /tmp/ssa-should-not-run' \
    --tools 'deny:rm' -y 'deny policy' \
    >/dev/null 2>&1
then
    fail "deny policy command"
fi

FOUND=""
for LOG in "$TMP/logs"/*.json
do
    [ -f "$LOG" ] || continue
    if jq -e '(.turns[-1].policy_violation.command == "rm")' "$LOG" >/dev/null
    then
        FOUND=$LOG
        break
    fi
done
[ -n "$FOUND" ] || fail "policy violation was not recorded in JSON log"

printf 'PASS: ssa tool policy tests\n'
