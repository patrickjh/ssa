#!/bin/sh
# testMaxModelCalls.sh — --max-model-calls N stops with exit 1 and the
# hit-max message. The replies never signal done, so the limit is what
# stops the run.

set -u
COMMUNITY_FOLDER=${COMMUNITY_FOLDER:-$(CDPATH= cd -- \
    "$(dirname "$0")/.." && pwd)}
. "$COMMUNITY_FOLDER/testUtils.sh"

test_max_model_calls() {
    write_script_reply "$REPLIES_FOLDER/reply1.txt" 'printf step-one'
    write_script_reply "$REPLIES_FOLDER/reply2.txt" 'printf step-two'
    run_ssa --max-model-calls 1 keep going forever
    expect_exit 1 || return 1
    expect_stderr_has \
        'hit max: stopped after SSA_MAX_MODEL_CALLS (1)' || return 1
}

run_test '--max-model-calls stops with hit-max message' \
    test_max_model_calls

finish_if_standalone
