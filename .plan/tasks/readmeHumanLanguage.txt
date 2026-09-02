readmeHumanLanguage — plain words in README.md

Why:
README is the human intro. Some lines read like AGENTS.md (command -v,
tee, -c, chat-completions path). Humans need try-it and safety, not
harness internals.

Do:
Rewrite README.md in short, plain sentences. Keep flag names, env
vars, and the example commands accurate. Keep the sandbox wrapper
example unless dropSandbox.txt has landed (then ask only; isolation
is wrap ssa). Say what examples do without assuming tee or setsid.
Do not copy Design from AGENTS.md. Do not change ssa or -h.

Size:
0 lines in `ssa`. Do not change ssa or -h.

No new tests.
