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

Doing this also lets you drop every "; see ssa -h for help"
on die strings, and the same pattern in AGENTS.md Error
messages. Those clauses exist because -h is the usage page.
Once README holds flags and env, the first clause already
names the setting (set SSA_URL). Do not retarget them at
README.md.

If you eliminate HELP_TEXT: still parse -h / --help so they are
not a task and not "bad option". Print one or two lines that name
README.md (and maybe the GitHub URL) and exit 0. Do not stop
checking for the flags.

Do not treat -h as a task word. Do not make unknown -* silent.
Do not copy Design from AGENTS.md into README. Do not grow -h
by moving README recipes into it.

readmeHumanLanguage.txt says do not change ssa or -h; that task
is the plain-words rewrite. Land that first, or fold the usage
move into it so README is rewritten once. helpExitStatus.txt is
one line if -h still exits 0; it is nothing if HELP_TEXT goes
away and the stub still exits 0. Settings are env only; -h remains.
This task is only about help text.

Size:
If no: 0. If reduce: about 40–50 lines removed from HELP_TEXT,
a few in README, and drop "; see ssa -h for help" from die
strings and AGENTS.md.
If eliminate HELP_TEXT: ~70 lines out of ssa plus dropping
those die clauses (~15 sites) and AGENTS.md (Flags and
defaults: ./ssa -h; keep -h short; requested help on stdout;
the Error messages "; see ssa -h for help" pattern). Tests
and README are extra, not in that count.

Tests:
If no: none. If reduce: showHelp still covers -h / --help, exit 0,
stdout, empty stderr; expect a short usage string, not the old
Environment table. If the stub only names README: change
showHelpWithDashH / showHelpWithLongOption to that string. Keep
no model call and no temp session. A mistyped flag still dies.
unknownDashOptionIsBadOption currently matches
"see ssa -h for help"; drop that once the die clause is gone.
