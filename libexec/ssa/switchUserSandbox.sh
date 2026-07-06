#!/bin/sh
# Script runner: runs shell scripts from the AI model as a different user.
# Set SSA_SCRIPT_RUNNER or --script-runner to the path of this file to use.
# This is the traditional Unix model, weaker than some other options but simple.
#
# Limits:
# World-readable host files remain readable.
# Network is not blocked.
# Symlinks may reach paths the sandbox user can open.
# The sandbox user can still destroy files it has access to.
# Need doas or sudo on PATH and passwordless permission to switch to the user.
#
# One-time setup (as root or your admin tools):
#   1. Create a login user, e.g. ssa-sandbox, with shell /bin/sh.
#   2. cd to your project before ssa
#   3. grant the sandbox user access to that tree.
#   4. Keep your real home directory mode 700;
#   5. Make sure no secrets are in the project tree.
#   6. Allow your login user to become ssa-sandbox without a password:
#      sudoers NOPASSWD for "sudo -u ssa-sandbox"
#      doas.conf "permit nopass yourlogin as ssa-sandbox" for doas

. "$(dirname "$0")/utils.sh"

SSA_SANDBOX_USER="${SSA_SANDBOX_USER:-}"
SCRIPT_FILE=""

main() {
    check_can_run
    read_script_into_session_file
    run_command_as_other_user
}

check_can_run() {
    [ -n "$SSA_SANDBOX_USER" ] ||
        util_die 'SSA_SANDBOX_USER not set; see ssa -h'
    id -u "$SSA_SANDBOX_USER" >/dev/null 2>&1 ||
        util_die "sandbox user not found: $SSA_SANDBOX_USER; " \
        "SSA_SANDBOX_USER must be an existing login user"
    [ "$(id -u)" -ne 0 ] ||
        util_die "refusing to run as root; use your login account and " \
        "a dedicated sandbox user"
    [ "$(id -un)" != "$SSA_SANDBOX_USER" ] ||
        util_die "sandbox user is the current user; " \
        "SSA_SANDBOX_USER must be a different login user"
    [ "$(id -u "$SSA_SANDBOX_USER")" -ne 0 ] ||
        util_die 'refusing to run scripts as root'
}

read_script_into_session_file() {
    util_check_session_folder
    SCRIPT_FILE="${SSA_SESSION_FOLDER}/switchUserScript${SSA_MODEL_CALLS}.txt"
    util_create_file_no_overwrite "$SCRIPT_FILE" ||
        util_die "session log not available: $SCRIPT_FILE"
    cat >"$SCRIPT_FILE" || util_die 'cannot read script from stdin'
    if [ ! -s "$SCRIPT_FILE" ]; then util_die 'empty script on stdin'; fi
}

run_command_as_other_user() {
    if command -v sudo >/dev/null 2>&1; then
        cat "$SCRIPT_FILE" | sudo -u "$SSA_SANDBOX_USER" -- sh
    elif command -v doas >/dev/null 2>&1; then
        cat "$SCRIPT_FILE" | doas -u "$SSA_SANDBOX_USER" -- sh
    else
        util_die 'need sudo or doas on PATH to change user'
    fi
    exit $?
}

main "$@"
