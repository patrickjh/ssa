#!/bin/sh
# Offline stand-in for curl used by the single-file ssa test suite.
# See markdownForAgents/TESTS.md for the reply-file contract.

set -u

[ -n "${SSA_STUB_REPLIES_FOLDER:-}" ] || {
    printf 'fakeCurl: SSA_STUB_REPLIES_FOLDER not set\n' >&2
    exit 1
}

COUNT_FILE="${SSA_STUB_REPLIES_FOLDER}/.curl_count"
COUNT=0
if [ -f "$COUNT_FILE" ]; then
    COUNT=$(cat "$COUNT_FILE")
fi
COUNT=$((COUNT + 1))
printf '%s\n' "$COUNT" >"$COUNT_FILE" || exit 1

REPLY_FILE="${SSA_STUB_REPLIES_FOLDER}/reply${COUNT}.txt"
[ -f "$REPLY_FILE" ] || {
    printf 'fakeCurl: no canned reply: %s\n' "$REPLY_FILE" >&2
    exit 1
}

FIRST_LINE=$(sed -n '1p' "$REPLY_FILE")
if [ "$FIRST_LINE" = "CURL_FAIL" ]; then
    exit 22
fi

OUT_FILE=""
HEADERS_FILE=""
PREV=""
for ARG in "$@"; do
    if [ "$PREV" = "-o" ]; then
        OUT_FILE=$ARG
    fi
    if [ "$PREV" = "-D" ]; then
        HEADERS_FILE=$ARG
    fi
    PREV=$ARG
done

[ -n "$OUT_FILE" ] || {
    printf 'fakeCurl: missing -o output file\n' >&2
    exit 1
}

command -v jq >/dev/null 2>&1 || {
    printf 'fakeCurl: jq not found on PATH\n' >&2
    exit 1
}

jq -n --rawfile content "$REPLY_FILE" \
    '{choices: [{message: {content: $content}}]}' >"$OUT_FILE" || exit 1

if [ -n "$HEADERS_FILE" ]; then
    printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n' \
        >"$HEADERS_FILE" || exit 1
fi

printf '200'
exit 0
