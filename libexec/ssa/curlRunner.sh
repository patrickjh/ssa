#!/bin/sh
# Model runner using curl and an OpenAI-compatible API.
# Reads prompt on stdin, uses curl to POST to API, writes reply on stdout.
# Retries on transient network errors, fails on non-transient errors.

. "$(dirname "$0")/utils.sh"

CURL_EXIT_OK=0
IS_TRUE=0
IS_FALSE=1
DEFAULT_RETRY_SLEEP_SECONDS=5
OPENAI_URL="${OPENAI_URL:-}"
SSA_MAX_CURL_CALLS="${SSA_MAX_CURL_CALLS:-5}"
SSA_CURL_ARGS="${SSA_CURL_ARGS:-}"
PROMPT_FILE=""
REQUEST_FILE=""
HEADERS_FILE=""
RESPONSE_FILE=""
HTTP_CODE_FILE=""
CURL_EXIT_FILE=""

main() {
    check_can_run
    setup_prompt_file
    build_json_request
    send_json_request_with_retries
    print_model_reply
}

check_can_run() {
    util_check_session_folder
    check_max_curl_calls
    check_openai_model_set
    check_openai_url
    check_runner_tool_on_path curl
    check_runner_tool_on_path jq
}

check_max_curl_calls() {
    case $SSA_MAX_CURL_CALLS in
    *[!0-9]*) util_die "SSA_MAX_CURL_CALLS must be a positive integer " \
        "(got $SSA_MAX_CURL_CALLS)" ;;
    esac
    [ "$SSA_MAX_CURL_CALLS" -ge 1 ] ||
        util_die "SSA_MAX_CURL_CALLS must be at least 1 " \
        "(got $SSA_MAX_CURL_CALLS)"
}

check_openai_model_set() {
    [ -n "$SSA_MODEL" ] ||
        util_die 'model not set; use ssa -m / --model or SSA_MODEL'
}

check_openai_url() {
    [ -n "$OPENAI_URL" ] ||
        util_die 'OPENAI_URL not set; set full https://…/chat/completions URL ' \
            '(e.g. https://api.openai.com/v1/chat/completions); ssa -h for help'
    printf '%s' "$OPENAI_URL" |
        grep -Eq '^https://[^[:space:]]+/chat/completions$' ||
        util_die "OPENAI_URL must be full https://…/chat/completions URL " \
            "(got $OPENAI_URL); ssa -h for help"
}

check_runner_tool_on_path() {
    command -v "$1" >/dev/null 2>&1 ||
        util_die "$1 not found on PATH"
}

setup_prompt_file() {
    PROMPT_FILE="${SSA_SESSION_FOLDER}/prompt${SSA_MODEL_CALLS}CurlPrompt.txt"
    util_create_file_no_overwrite "$PROMPT_FILE" ||
        util_die "temp file not available: $PROMPT_FILE"
    cat >"$PROMPT_FILE" || util_die 'cannot read prompt from stdin'
}

build_json_request() {
    REQUEST_FILE="${SSA_SESSION_FOLDER}/prompt${SSA_MODEL_CALLS}CurlRequest.txt"
    util_create_file_no_overwrite "$REQUEST_FILE" ||
        util_die "temp file not available: $REQUEST_FILE"
    jq -n \
        --arg model "$SSA_MODEL" \
        --rawfile content "$PROMPT_FILE" \
        '{model: $model, messages: [{role: "user", content: $content}]}' \
        >"$REQUEST_FILE" || util_die 'cannot build curl request JSON'
}

send_json_request_with_retries() {
    HTTP_ATTEMPT=0
    while [ "$HTTP_ATTEMPT" -lt "$SSA_MAX_CURL_CALLS" ]; do
        HTTP_ATTEMPT=$((HTTP_ATTEMPT + 1))
        setup_attempt_logs
        send_json_request
        if request_succeeded; then break; else exit_or_retry; fi
    done
}

setup_attempt_logs() {
    PATH_PREFIX="${SSA_SESSION_FOLDER}/prompt${SSA_MODEL_CALLS}"
    HEADERS_FILE="${PATH_PREFIX}CurlHeaders${HTTP_ATTEMPT}.txt"
    RESPONSE_FILE="${PATH_PREFIX}CurlResponse${HTTP_ATTEMPT}.txt"
    HTTP_CODE_FILE="${PATH_PREFIX}CurlHttpCode${HTTP_ATTEMPT}.txt"
    CURL_EXIT_FILE="${PATH_PREFIX}CurlExit${HTTP_ATTEMPT}.txt"
    util_create_file_no_overwrite "$HEADERS_FILE" ||
        util_die "temp file not available: $HEADERS_FILE"
    util_create_file_no_overwrite "$RESPONSE_FILE" ||
        util_die "temp file not available: $RESPONSE_FILE"
    util_create_file_no_overwrite "$HTTP_CODE_FILE" ||
        util_die "temp file not available: $HTTP_CODE_FILE"
    util_create_file_no_overwrite "$CURL_EXIT_FILE" ||
        util_die "temp file not available: $CURL_EXIT_FILE"
}

send_json_request() {
    # shellcheck disable=SC2086
    curl -sS \
        -H "Content-Type: application/json" \
        ${OPENAI_API_KEY:+-H "Authorization: Bearer $OPENAI_API_KEY"} \
        -D "$HEADERS_FILE" -o "$RESPONSE_FILE" -w '%{http_code}' \
        $SSA_CURL_ARGS \
        -d @"$REQUEST_FILE" \
        "$OPENAI_URL" >"$HTTP_CODE_FILE"
    printf '%s' "$?" >"$CURL_EXIT_FILE" ||
        util_die "cannot write session log: $CURL_EXIT_FILE"
}

request_succeeded() {
    if [ "$(cat "$CURL_EXIT_FILE")" -ne "$CURL_EXIT_OK" ]; then
        return $IS_FALSE
    fi
    case $(cat "$HTTP_CODE_FILE") in
        *[!0-9]*) return $IS_FALSE ;;
    esac
    if [ "$(cat "$HTTP_CODE_FILE")" -ge 200 ]; then
        if [ "$(cat "$HTTP_CODE_FILE")" -lt 300 ]; then
            return $IS_TRUE
        fi
    fi
    return $IS_FALSE
}

exit_or_retry() {
    if [ "$(cat "$CURL_EXIT_FILE")" -eq "$CURL_EXIT_OK" ]; then
        exit_if_insufficient_quota
        exit_if_http_code_not_retryable
    fi
    exit_if_too_many_retries
    sleep_before_retry
}

exit_if_insufficient_quota() {
    if [ "$(cat "$HTTP_CODE_FILE")" = 429 ]; then
        if jq -e '.error.code == "insufficient_quota"' "$RESPONSE_FILE" \
            >/dev/null 2>&1; then
            util_die "quota exceeded; retry will not help; " \
                "check OPENAI_API_KEY and API billing"
        fi
    fi
}

exit_if_http_code_not_retryable() {
    case $(cat "$HTTP_CODE_FILE") in
    429|408|500|502|503|504) return ;;
    *) util_die "HTTP $(cat "$HTTP_CODE_FILE") not retryable; " \
        "check OPENAI_API_KEY, OPENAI_URL (full …/chat/completions URL), " \
        "and SSA_MODEL" ;;
    esac
}

exit_if_too_many_retries() {
    [ "$HTTP_ATTEMPT" -lt "$SSA_MAX_CURL_CALLS" ] ||
        util_die "curl calls exhausted after $SSA_MAX_CURL_CALLS attempts; " \
        "raise SSA_MAX_CURL_CALLS to allow more"
}

sleep_before_retry() {
    HEADER_VALUE=$(grep -i '^Retry-After:' "$HEADERS_FILE" 2>/dev/null |
        sed -n '1p' | sed 's/^[^:]*:[[:space:]]*//' | tr -d '\r')
    case $HEADER_VALUE in
    ''|*[!0-9]*) sleep "$DEFAULT_RETRY_SLEEP_SECONDS" ;;
    *) sleep "$HEADER_VALUE" ;;
    esac
}

print_model_reply() {
    REPLY=$(jq -r '.choices[0].message.content // empty' "$RESPONSE_FILE")
    if [ -z "$REPLY" ]; then exit 1; fi
    printf '%s\n' "$REPLY"
}

main "$@"
