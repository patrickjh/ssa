#!/bin/sh
set -u
TESTS_FOLDER=${TESTS_FOLDER:-$(CDPATH= cd -- "$(dirname "$0")" && pwd)}
. "$TESTS_FOLDER/testUtils.sh"

test_max_model_prompts() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" 'printf step-one'
    write_script_reply "$REPLIES_FOLDER/reply2.txt" 'printf step-two'
    run_ssa --max-model-prompts 1 keep going forever
    expect_exit 1 || return 1
    expect_stderr_has \
        'hit max: stopped after SSA_MAX_MODEL_PROMPTS (1)' || return 1
}

run_test '--max-model-prompts stops with hit-max message' \
    test_max_model_prompts

finish_if_standalone
