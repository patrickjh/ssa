readmeHumanLanguage — plain words in README.md

Why:
README is the human intro. Some lines read like AGENTS.md (command -v,
tee, -c, chat-completions path). Humans need try-it and safety, not
harness internals.

Do:
Rewrite README.md in short, plain sentences. Keep flag names, env
vars, and the example commands accurate. Keep the sandbox wrapper
example; say what it does without assuming the reader knows tee or
setsid. Do not copy Design from AGENTS.md. Do not change ssa or -h.

No new tests.
