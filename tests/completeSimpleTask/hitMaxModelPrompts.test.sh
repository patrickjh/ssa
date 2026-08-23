#!/bin/sh
# Model never sends "# task complete". Stop after --max-model-prompts.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
printf 'still working\n'
REPLY

add_model_reply 2 <<'REPLY'
printf 'still working\n'
REPLY

run_ssa_task --max-model-prompts 2 never finish this task
expect_exit 1
expect_stderr_has 'hit max: stopped after SSA_MAX_MODEL_PROMPTS (2)'
