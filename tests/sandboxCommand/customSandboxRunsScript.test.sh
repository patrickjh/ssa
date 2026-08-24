#!/bin/sh
# A custom sandbox command runs the model script (marker on stdout).

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

require_test_temp_folder
STUB="$TEST_TEMP_FOLDER/stubSandboxCommand"
cat >"$STUB" <<'STUB' || fail "cannot write stub sandbox command"
#!/bin/sh
printf 'STUB_SANDBOX_COMMAND_RAN\n'
exec sh "$@"
STUB
chmod +x "$STUB" || fail "cannot make stub sandbox command executable"

add_model_reply 1 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 2 <<'REPLY'
# task complete
REPLY

run_ssa_task --sandbox-command "$STUB" print a greeting then stop
expect_exit 0
expect_stdout_has 'STUB_SANDBOX_COMMAND_RAN'
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: task complete after 2 model prompts'
