# ssa — Simple Shell Agent

A simple AI coding agent written in less than 1,000 lines of mostly 
POSIX `sh` shell scripts. You give it a task in plain
English; it asks a model what shell commands to run, runs them, shows the
model the output, and repeats until the job is done.

Inspired by [mini-swe-agent](https://github.com/SWE-agent/mini-swe-agent):
**shell only**, **fresh process each step**, **simple loop**.

## Quick start

Clone the repo, set some environment variables and you're good to go:

```sh
export PATH="/path/to/ssa/bin:$PATH"

export OPENAI_API_KEY="sk-..."
export OPENAI_URL="https://openrouter.ai/api/v1/chat/completions"
export SSA_MODEL_RUNNER="/path/to/ssa/libexec/ssa/curlRunner.sh"
export SSA_MODEL="openrouter/auto"

cd /path/to/your/project
ssa summarize this repo
```

Run `ssa -h` for all options.

## Dependencies

The core agent loop is written in pure POSIX `sh`
This core code only uses POSIX `sh`, `date`, `grep`, `sed`, and `tee`.
But to get replies from a model you need some non POSIX tools:

The bundled HTTP runner (`curlRunner.sh`) queries OpenAI compatible APIs
This depends on `curl` and `jq`

The bundled local AI runner (`llamaCppRunner.sh`) uses [llama.cpp](https://github.com/ggml-org/llama.cpp)
Their `llama-completion` tool must be on your PATH

Those tools should all work fine on Linux, macOS, and BSD, but that is why
this is called "Mostly POSIX `sh`". POSIX `sh` except getting model results.

## How the agent works (short version)

1. You pass a task on the command line (or pipe it on stdin).
2. The agent sends a transcript with the task to your model.
3. The model replies with a small shell script to help with the task.
4. The agent runs that script in your current directory
5. The agent feeds the output from that command back to the model.
5. Repeat until the model signals it is done.

## Safety

By default, `ssa` runs model-generated shell commands **as your user**, with
**your environment**, in whatever directory you run it from.
Treat it like handing your terminal to the model.

You can apply sandboxing using `--script-runner` or `SSA_SCRIPT_RUNNER`.
These take a file path to a "Script Runner".
That Script Runner file will be executed and passed the script the AI model wants to run on stdin.
These Script Runner files are supposed to apply sandboxing, run the
script the model sent, and then send the stdout and stderr from running that
script back to the AI agent harness to be sent to the terminal and model.

Two "Script Runners" that apply simple sandboxing are included:

`libexec/ssa/askUserSandbox.sh` — ask the user before running each script
`libexec/ssa/switchUserSandbox.sh` — run scripts as another Unix user

Serious usage may want to create more complex sandboxes for the scripts
the AI model wants to run using seccomp / namespaces / pledge() / jails etc.

## Debugging

Session files are written under `$TMPDIR/ssa-$LOGNAME-<timestamp>/`. Pass
`--keep-session` to keep them after exit. We try to log a lot of the files
created by the agent harness and sandbox so you can debug the various steps.
A good starting point is sessionTranscript.txt which shows the run of the agent
harness from the view of the model.

## Models

The smallest AI models can struggle to use this as they do not really respond
with answers that can be parsed by our simple parsing logic. Specifically,
I failed to get usable results when doing some simple tests with Qwen 2.5 - 1.5B
and Qwen 2.5 - 3B models. However, models such as Qwen 2.5 - 7B and Qwen 2.5 - 32B
were able to produce results that could be parsed into runnable shell scripts
for very simple "hello world" type tasks. So just be aware this might not work
with the smallest models.


## License

MIT — see [LICENSE](LICENSE).
