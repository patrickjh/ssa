#!/bin/sh
# Exported PID / PROMPT_COUNTER / TEMP_FOLDER from the caller do not
# reach the sandbox script.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'PID=%s\n' "${PID-unset}"
printf 'PROMPT_COUNTER=%s\n' "${PROMPT_COUNTER-unset}"
printf 'TEMP_FOLDER=%s\n' "${TEMP_FOLDER-unset}"
REPLY

add_model_reply 2 <<'REPLY'
# complete
REPLY

export PID=from-caller
export PROMPT_COUNTER=99
export TEMP_FOLDER=/from-caller
run_ssa_task print whether private names leaked
expect_exit 0
expect_stdout_has 'PID=unset'
expect_stdout_has 'PROMPT_COUNTER=unset'
expect_stdout_has 'TEMP_FOLDER=unset'
expect_stderr_has 'done: after 2 model prompts'
