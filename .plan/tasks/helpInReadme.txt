helpInReadme — usage lives in README, shrink or drop -h

Why:
HELP_TEXT is ~70 lines of ssa. README already introduces the tool
and currently defers "Full usage and defaults" to ssa -h. Two
places to update when a flag or default changes. The Environment
"See --foo" table in help is already more than AGENTS.md wants
(-h: flags, one loop paragraph, exit codes; no README recipes).
Undecided how far to go. Do not treat this as required work.

This is a maybe. Full delete of -h fights Unix convention (this
repo follows that unless there is a deliberate exception) and
the file-alone install ("download the ssa file alone"). People
type ssa -h first. die strings say "see ssa -h for help".

Do:
Decide first. Preferred: reduce, do not eliminate. Put the flag
and env table in README.md (the human usage page). Keep parsing
-h and --help. Keep them printing a short synopsis on stdout,
exit 0: usage line, required settings, flag names, one loop
paragraph, exit codes. Point at README.md for the rest. Drop the
Environment table and long per-flag paragraphs from HELP_TEXT.

If you eliminate HELP_TEXT: still parse -h / --help so they are
not a task and not "bad option". Print one or two lines that name
README.md (and maybe the GitHub URL) and exit 0. Do not stop
checking for the flags. Rewrite die hints that say
"see ssa -h for help" to name README.md or keep a tiny -h that
those hints can still mean.

Do not treat -h as a task word. Do not make unknown -* silent.
Do not copy Design from AGENTS.md into README. Do not grow -h
by moving README recipes into it.

readmeHumanLanguage.txt says do not change ssa or -h; that task
is the plain-words rewrite. Land that first, or fold the usage
move into it so README is rewritten once. helpExitStatus.txt is
one line if -h still exits 0; it is nothing if HELP_TEXT goes
away and the stub still exits 0. envOnlySettings.txt keeps -h
even if other flags die; this task is only about help text, not
about dropping --model / --no-ask.

Size:
If no: 0. If reduce: about 40–50 lines removed from HELP_TEXT,
a few in README, die hints unchanged if they still say ssa -h.
If eliminate HELP_TEXT: ~70 lines out of ssa plus rewriting
"see ssa -h" (~15 die sites) and AGENTS.md (Flags and defaults:
./ssa -h; keep -h short; requested help on stdout). Tests and
README are extra, not in that count.

Tests:
If no: none. If reduce: showHelp still covers -h / --help, exit 0,
stdout, empty stderr; expect a short usage string, not the old
Environment table. If the stub only names README: change
showHelpWithDashH / showHelpWithLongOption to that string. Keep
no model call and no temp session. A mistyped flag still dies.
