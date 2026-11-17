# test version

This folder is a trial copy. The programs in the repo root
are unchanged. Put this folder on `PATH` so a script can
call `ssa-edit` and `ssa-ask`, and so `ssa` can mention
them in the system prompt.

```sh
export PATH="/path/to/testVersion:$PATH"
export SSA_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL=gpt-4o-mini
export SSA_KEY="sk-..."
export SSA_BACKUP_MODEL=/models/gemma.gguf
ssa -v summarize this file
```

A reply is a POSIX `sh` script. `# complete` alone ends the
run. As the last line of a script, it ends the run when
that script exits 0. There is no `# write`, `# edit`, or
`# chat`.

`-v`, `-y`, `-m`, and `-l` may come before the task. `-v`
sets `SSA_VERBOSE=1`. `-y` sets `SSA_ASSUME_YES=1`. `-m`
sets `SSA_MODEL` for the cloud. `-l` skips the cloud and
starts the local server. `--` ends the flags.

## Cloud and local

Without `-l`, `ssa` probes `SSA_URL` once. Any HTTP
response, including 401, 404, and 405, means the cloud is
up and the run uses it.

A refused connection (curl exit 7) or a timeout (curl
exit 28) is tried once more and then the run stops. It
does not start the local server.

`Network is unreachable`, `No route to host`, and
`unreachable network` mean there is no internet. The run
then starts `llama-server` on `SSA_BACKUP_MODEL`, waits
on `/health`, and uses that server. The model name
becomes `local`. A fallback prints one line on stderr.
Pass `-v` to see the probe notes.

A name that does not resolve is a failure, not a
fallback. That choice is open: being offline often looks
the same as a typo in `SSA_URL`.

`-l` always starts the local server. A local failure does
not contact `SSA_URL`. The server gets four flags:
`--model`, `--alias local`, `--host 127.0.0.1`, and
`--port`. If that port already answers `/health`, the
run stops.

Later model calls still retry a refused connection the
way the root `ssa` does. They do not switch to local in
the middle of a run.

## ssa-edit

One path argument. The search/replace block is on stdin.
Use a quoted heredoc. The file must already exist.

```sh
ssa-edit hello.txt <<"EOF"
<<<<<<< SEARCH
hello
=======
hello
world
>>>>>>> REPLACE
EOF
```

The search block must be non-empty and match exactly
once. A search or replace line must not be exactly
`=======` or `>>>>>>> REPLACE`.

## ssa-ask

No arguments. The question is on stdin. It is shown on
`/dev/tty`. One line is read from `/dev/tty` and written
on stdout. An empty line writes `The user sent no text.`

```sh
answer=$(ssa-ask <<"EOF"
Which file should I edit?
EOF
)
```

## Settings

| Setting | Default |
| --- | --- |
| `SSA_ASSUME_YES` | `0` (ask before a script) |
| `SSA_BACKUP_MODEL` | empty; GGUF used by `-l` and by a no-internet fallback |
| `SSA_EXTRA_SYSTEM_TEXT` | empty, added after the tool notes |
| `SSA_KEY` | empty; bearer token when the cloud needs one |
| `SSA_LOG_FOLDER` | `TMPDIR`, or `/tmp` |
| `SSA_MAX_CONTEXT_BYTES` | `0` (send every turn) |
| `SSA_MAX_MODEL_PROMPTS` | `20` (`0` means no limit) |
| `SSA_MODEL` | required for the cloud; `-l` and fallback set `local` |
| `SSA_REQUEST_JSON` | empty; extra JSON object merged into the body |
| `SSA_SERVER_PORT` | `8080` |
| `SSA_SERVER_WAIT` | `120` seconds for `/health` |
| `SSA_URL` | required unless `-l` |
| `SSA_VERBOSE` | `0` |

Each run writes one JSON log. It stays. It cannot be
turned off. The log `url` is the server the run used.
`USE_LOCAL=1` in the settings means `-l` was set. A
local `url` with `USE_LOCAL=0` means the no-internet
fallback.

### Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task completed |
| 1 | Bad arguments, harness failure, or the prompt limit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |
