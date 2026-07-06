#!/bin/sh
# Simple model runner using llama.cpp.
# Reads prompt on stdin, sends to llama-completion, writes reply on stdout.

. "$(dirname "$0")/utils.sh"

OUTPUT_FILE=""
PROMPT_FILE=""
LLAMA_COMPLETION_EXIT=0

main() {
    check_can_run
    setup_prompt_file
    setup_output_file
    run_llama_completion
    if [ "$LLAMA_COMPLETION_EXIT" -eq 0 ]; then print_model_output; fi
    exit "$LLAMA_COMPLETION_EXIT"
}

check_can_run() {
    util_check_session_folder
    [ -n "$SSA_MODEL" ] ||
        util_die 'model not set; use ssa -m / --model or SSA_MODEL'
    [ -f "$SSA_MODEL" ] ||
        util_die "model file not found: $SSA_MODEL; " \
        "use ssa -m / --model or SSA_MODEL"
    command -v llama-completion >/dev/null 2>&1 ||
        util_die 'llama-completion not found on PATH'
}

setup_prompt_file() {
    PROMPT_FILE="${SSA_SESSION_FOLDER}/prompt${SSA_MODEL_CALLS}LlamaCppPrompt.txt"
    util_create_file_no_overwrite "$PROMPT_FILE" ||
        util_die "temp file not available: $PROMPT_FILE"
    cat >"$PROMPT_FILE" || util_die 'cannot read prompt from stdin'
}

setup_output_file() {
    OUTPUT_FILE="${SSA_SESSION_FOLDER}/prompt${SSA_MODEL_CALLS}LlamaCppOutput.txt"
    util_create_file_no_overwrite "$OUTPUT_FILE" ||
        util_die "temp file not available: $OUTPUT_FILE"
}

run_llama_completion() {
    # shellcheck disable=SC2086
    llama-completion \
        -m "$SSA_MODEL" \
        -f "$PROMPT_FILE" \
        -no-cnv \
        --simple-io \
        --color off \
        --no-display-prompt \
        --log-verbosity 1 \
        --no-warmup \
        -n 1024 \
        $LLAMA_CPP_ARGS >"$OUTPUT_FILE"
    LLAMA_COMPLETION_EXIT=$?
}

print_model_output() {
    SED_TRIM_LLAMACPP_END='$ s/[[:space:]]*\[end of text\][[:space:]]*$//'
    sed "$SED_TRIM_LLAMACPP_END" "$OUTPUT_FILE"
}

main "$@"
