# Show help

As a user, I run `ssa -h` or `ssa --help` to learn how to use the tool
without starting an agent run.

## Acceptance

- Exit code is 0
- Help text is printed on **stdout**
- Output includes recognizable usage (`-h`, `--help`) and a required
  setting such as `OPENAI_URL`
- Stderr is empty for a successful help request
- No model call and no temp agent session are required
