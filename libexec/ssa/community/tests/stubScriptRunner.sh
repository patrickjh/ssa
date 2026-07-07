#!/bin/sh
# stubScriptRunner.sh — offline script runner for the sanity tests.
# Runs the model script in a fresh sh, but first prints a marker so a
# test can prove the harness routed the script through the configured
# script runner (SSA_SCRIPT_RUNNER) rather than the built-in path.
#
# Contract (same as any ssa script runner):
#   stdin      the model script text
#   stdout     script stdout, plus this runner's own messages
#   stderr     script stderr, plus this runner's diagnostics
#   exit code  the model script's exit code (captured by the harness)

set -u

printf 'STUB_SCRIPT_RUNNER_RAN\n'
sh
