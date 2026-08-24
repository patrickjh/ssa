#!/bin/sh
# Two markdown fences are a format error; the inner scripts are not run.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

add_model_reply 1 <<'REPLY'
```sh
printf 'first-fence\n'
```

```sh
printf 'second-fence\n'
```
REPLY

add_model_reply 2 <<'REPLY'
printf 'hello-from-script\n'
REPLY

add_model_reply 3 <<'REPLY'
# task complete
REPLY

run_ssa_task print a greeting then stop
expect_exit 0
expect_stdout_has 'Format error'
expect_stdout_lacks 'first-fence'
expect_stdout_lacks 'second-fence'
expect_stdout_has 'hello-from-script'
expect_stderr_has 'done: task complete after 3 model prompts'
