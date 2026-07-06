#!/bin/sh
# Simple script runner: shows AI script on stderr and asks user to approve
# before running. Yes runs the script, No rejects, Quit stops ssa.
# Set SSA_SCRIPT_RUNNER or --script-runner to the path of this file to use.

. "$(dirname "$0")/utils.sh"

PROMPT_DEVICE="/dev/tty"
SCRIPT_FILE=""
ANSWER_FILE=""

main() {
    read_script_into_session_file
    check_prompt_device
    ask_user
}

read_script_into_session_file() {
    util_check_session_folder
    SCRIPT_FILE="${SSA_SESSION_FOLDER}/askUserScript${SSA_MODEL_CALLS}.txt"
    util_create_file_no_overwrite "$SCRIPT_FILE" ||
        util_die "session log not available: $SCRIPT_FILE"
    cat >"$SCRIPT_FILE" || util_die 'cannot read script from stdin'
    if [ ! -s "$SCRIPT_FILE" ]; then util_die 'empty script on stdin'; fi
}

check_prompt_device() {
    [ -r "$PROMPT_DEVICE" ] ||
        util_die "need /dev/tty to read answer; use --script-runner " \
        "without askUserSandbox in batch runs"
}

ask_user() {
    ANSWER_FILE="${SSA_SESSION_FOLDER}/askUserAnswer${SSA_MODEL_CALLS}.txt"
    printf 'Script from model:\n' >&2
    cat "$SCRIPT_FILE" >&2
    while true; do
        printf 'Run this script? [Y]es / [N]o / [Q]uit ' >&2
        read_answer_from_tty_to_session
        case $(cat "$ANSWER_FILE") in
        y|Y|yes|YES) run_approved_script ;;
        n|N|no|NO) reject_script ;;
        q|Q|quit|QUIT) util_die 'User chose to quit.' ;;
        esac
    done
}

read_answer_from_tty_to_session() {
    IFS= read -r REPLY <"$PROMPT_DEVICE" || REPLY=""
    printf '%s\n' "$REPLY" >"$ANSWER_FILE" ||
        util_die "cannot write session log: $ANSWER_FILE"
}

run_approved_script() {
    cat "$SCRIPT_FILE" | sh
    exit $?
}

reject_script() {
    printf 'User chose not to run script. Try something else.\n'
    exit 1
}

main "$@"
