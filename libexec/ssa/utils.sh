#!/bin/sh
# Shared helpers for ssa model runners and script runners.
# Source: . "$(dirname "$0")/utils.sh"

util_check_session_folder() {
    if [ -z "${SSA_SESSION_FOLDER:-}" ] || [ ! -d "$SSA_SESSION_FOLDER" ]; then
        util_die 'SSA_SESSION_FOLDER not set; run via ssa'
    fi
    case ${SSA_MODEL_CALLS:-} in
        ''|*[!0-9]*) util_die 'SSA_MODEL_CALLS not set; run via ssa' ;;
    esac
}

util_create_file_no_overwrite() {
    ( umask 077; set -C; : >"$1" )
}

util_die() {
    printf '%s\n' "$*" >&2
    if [ -n "${SSA_PID:-}" ]; then
        kill -USR1 "$SSA_PID" 2>/dev/null
    else
        printf 'SSA_PID not set; cannot signal parent process\n' >&2
    fi
    exit 1
}
