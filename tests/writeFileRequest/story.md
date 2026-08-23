# Write a file with a write request

As a model, I create or overwrite a file with no heredoc and no shell
at all in my reply: the first line is exactly `# write file: PATH` and
every line after it is the raw file contents. ssa writes the rest of
the reply to PATH with `sed 1d` through the same ask and sandbox
layers as a script turn. No quoting or escaping applies to the
payload, and the mechanism does not depend on shell stdin-sharing
behavior.

## Acceptance

- The file lands byte-for-byte: quotes, dollars, backticks,
  backslashes, and trailing blank lines survive untouched
- Works both for creating a new file and overwriting an existing one
- A successful write prints `wrote file: PATH` on stdout (and so into
  the transcript)
- A write to a missing parent folder fails, the failure lands in the
  transcript, and a later script turn plus retried write recovers
- A first line `# write file:` with no path is not a write request; it
  runs as a script
- The run exits 0 after the `# task complete` reply
- No real network use: a fake `curl` on `PATH` serves canned
  chat-completions JSON replies
