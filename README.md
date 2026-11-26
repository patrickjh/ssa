# ssa

ssa is an AI agent as a single POSIX sh script that acts like a unix util.
You have to set various environment variables or CLI flags, then you
call ssa with the task as args. You can pass context on stdin.

ssa works with local models or cloud models. When using a cloud model,
ssa only has dependencies on jq, curl and CLI tools that are in the POSIX standard.
When using a local model you also need llama-server from llama.cpp on the PATH.

## Run with cloud model

To run ssa with a cloud model you have to set a few environment variables first.
SSA_URL must point to an open ai style chat completions url. SSA_KEY needs to
hold the auth key. SSA_MODEL holds the model name. Then you can start using ssa.

```sh
export SSA_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL=gpt-4o-mini
export SSA_KEY="your-api-key"
cat notes.txt | ssa -a summarize this file
```

## Run with local model

To run ssa with a local model, you need llama-server on PATH and a local
gguf file. You set SSA_MODEL to the path to that gguf file. You can also
use the -m arg to set SSA_MODEL. Then you just call ssa. ssa will
start llama-server on `127.0.0.1` and talks to it just like a cloud model.

```sh
export SSA_MODEL=/models/gemma.gguf
ssa -a summarize this folder
```

## ssa modes

By default ssa works in a single script mode. That is you pass in some text
and then ssa returns a single script ready to run. You get asked to approve the
script before it runs.

There is also an agent mode via -a. In this mode, the result of the first script
gets sent back as the second user turn, and the model returns a second script.
This continues until the model considers the original task is complete, the prompt
limit is hit, or you choose to quit.

## edits

By default, ssa only depends on POSIX shell tools. These are great, but there is
not a great POSIX shell tool that lets an agent edit a file. For that reason,
there is a # edit response type available in ssa.

`# edit` uses an Aider style search and replace edit. AI models do better at
editing files when this is available, but the smallest models can struggle
with it. For that reason `# edit` is turned off by default. To turn it on,
set SSA_EDITS=1.


## chat

As part of completing a task, an AI model may want to ask you a question.
Or you may just want to chat with an AI model. To enable that, ssa has a
`# chat` response type that is turned off by default.

With `# chat` the AI model responds with some text, and then there is a
chance for you to write back. Turn this on by setting SSA_CHAT=1

## tool policies

Use `--tools` or `SSA_TOOLS` to control model-generated shell commands:

```sh
ssa --tools "allow:ls,cat,grep,find" -a "inspect this project"

SSA_TOOLS="deny:rm,sudo,curl" ssa -a "review this code"
```

Policies have this syntax:

```text
allow:command1,command2
deny:command1,command2
```

An allow policy permits only the named commands. A deny policy permits
other commands except for the named commands. Command names must contain
only letters, digits, `_`, `.`, `+`, or `-`; paths and names with spaces
are invalid. `--tools` overrides `SSA_TOOLS` for that invocation.

The policy is included in the system prompt and is enforced again before
every script is executed, including with `SSA_YES=1` and `-y`. A
violation is not executed. ssa prints the blocked command name on stderr
and records `policy_violation` in that turn of the JSON run log. The log
does not include the rejected script or command arguments.

Enforcement covers command names in arguments, pipelines, command
chaining, redirections, shell substitutions, shell built-ins, and nested
execution constructs. Command substitution and backticks are rejected.
Dynamic command names, subshells, function and compound constructs that
cannot be validated safely, shell interpreters, and common command
launchers are rejected in the active policy mode. `# edit` is a direct
SEARCH/REPLACE file mutation rather than a shell command. It is allowed
only when `SSA_EDITS=1`, cannot execute its text, and does not bypass
the policy; a script produced afterward is checked normally.

This is command filtering, not a security sandbox. It does not isolate
files, the network, environment variables, devices, or privilege changes
performed through allowed commands or the host shell. In particular,
redirections and allowed tools can still read or write host files. Run
ssa in a container, VM, restricted account, or other OS sandbox if you
need hostile-process isolation.

Limitations: a policy must be fail closed. If ssa cannot safely
decompose a script, it rejects the script rather than guessing. Shell
extensions outside the POSIX constructs checked here are rejected.

## testing tool policies

The repository includes `test-ssa.sh`, which uses a mock `curl` and JSON
model response to test policy parsing and enforcement without a network
service:

```sh
cd "/Users/michaeoketunde/Documents/Projects/LessonsWithPatrick-protocol/ssa"
./test-ssa.sh
```

The cases cover allowed commands, blocked allow/deny commands, pipelines,
command substitution, shell built-ins, malformed policies, CLI precedence,
and `-y` mode.

## logging

ssa uses a json file on disk to run. This json file also serves as a log
of what happens when ssa runs. These json files are stored in a folder
pointed to be `SSA_LOGS`. If that is not set, these are stored in /tmp.

You can pass these logs back to an AI model to debug what went wrong
when you called ssa, or to review what is going on.

## Environment Variables

`VAR=value ssa …` covers one run. Each name is `SSA_`
and one word.

| Setting | Default | Description |
| --- | --- | --- |
| `SSA_AGENT` | `0` | `0` is one reply. `1` enables Agent mode, where the model works on the task over multiple replies. |
| `SSA_CHAT` | `0` | `1` allows a reply that starts with `# chat`. `0` leaves that marker as a comment. |
| `SSA_EDITS` | `0` | `1` allows a reply that starts with `# edit file: PATH`. `0` leaves that marker as a comment. |
| `SSA_EXTRA` | empty | Text added to the system prompt after the reply rules and before the task. Use this to create agents with custom system prompt. |
| `SSA_FLAGS` | empty | Extra CLI args for `llama-server`, after `--model`, `--alias local`, `--host 127.0.0.1`, and `--port`. Only useful when running a local model. |
| `SSA_JSON` | empty | A JSON object merged into the HTTP request sent to the cloud model. Useful if you need some custom parameters for your cloud API. |
| `SSA_KEY` | empty | Auth bearer token for the cloud AI model provider. Not written to the log. |
| `SSA_LIMIT` | `400000` | Maximum text sent to the AI model, in characters. ssa implements a sliding context window. This means The system text and the first user turn are always sent. Older messages and AI responses are dropped to get under this limit. A message still over the limit goes out as it is. `0` sends every turn. |
| `SSA_LOGS` | `TMPDIR`, or `/tmp` | Directory for ssa JSON logs. One log is written per run.|
| `SSA_MODEL` | required | A string that is either 1. A path to a gguf file that will be used as the local model with llama-server 2. The model name to pass to the cloud AI model provider. |
| `SSA_PORT` | empty | Port for the local server. Empty picks `20000` plus the process id modulo `10000`, then tries the next port up to 10 times. A set port that already answers stops the run. |
| `SSA_PROMPTS` | `20` | Maximum model calls in agent mode. `0` means no limit. Ignored when `SSA_AGENT` is `0`. |
| `SSA_REASONING` | `0` | `0`, `off`, or `none` sends `reasoning_effort` none. `1` or `on` omits the field. Any other word is the effort, such as `low` or `high`. Empty is an error. A server flag such as `--reasoning off` belongs in `SSA_FLAGS`. |
| `SSA_SCRIPTS` | `1` | `1` treats a non-marker reply as a script. `0` treats scripts as an error, and only allows # edit or # chat. |
| `SSA_TOOLS` | empty | Active command policy. Use `allow:ls,cat,grep,find` or `deny:rm,sudo,curl`. The `--tools` flag takes precedence for one run. |
| `SSA_URL` | empty | The OpenAI chat completions compatible URL for the cloud model provider. Required for using cloud models. When you set SSA_MODEL to a local model file, ssa sets this to the llama-server local server that ssa starts per run. |
| `SSA_VERBOSE` | `0` | `1` prints a lot of output on stderr which can be useful for debugging. `0` acts as a unix util and is quiet by default. |
| `SSA_WAIT` | `120` | Seconds to wait for the local server to answer `/health`. |
| `SSA_YES` | `0` | `1` skips the question and applies the script or a edit the model sends automatically. `1` does not skip a chat. When running ssa in the background or where you trust the model, set this to `1`. That also turns chat off. |

## CLI Args

Flags come before the task. I.e. 

```sh
ssa some task -v
```

is invalid, while
 
```sh 
 ssa -v some task
```
Works

| Arg | Sets | Description |
| --- | --- | --- |
| `-a` | `SSA_AGENT=1` | Agent mode. The model keeps working across replies. |
| `-m` | `SSA_MODEL` | The next word is the model name or the model file. |
| `--tools` | `SSA_TOOLS` | The next word is `allow:` or `deny:` command policy. Overrides `SSA_TOOLS` for this run. |
| `-v` | `SSA_VERBOSE=1` | Print short notes on stderr, and the local server text. |
| `-y` | `SSA_YES=1` | Skip the question and apply a script or an edit. |
| `--` | | Ends the flags, so a task can start with a dash. |

## Exit status

| Code | Meaning |
| --- | --- |
| 0 | The task is done, or the person quits. Yes on the default path returns the script or action exit code |
| 1 | Bad arguments, a harness failure, the server did not start, or the prompt limit |
| 129 | Hangup |
| 130 | Interrupt |
| 143 | Terminate |

Hangup, interrupt, and terminate print no status line.

cd "/Users/michaeoketunde/Documents/Projects/LessonsWithPatrick-protocol/ssa"
chmod +x ssa

export SSA_URL="https://api.openai.com/v1/chat/completions"
export SSA_MODEL="gpt-4o-mini"
export SSA_KEY="your-api-key"

./ssa -a "summarize the current directory"