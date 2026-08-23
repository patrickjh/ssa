# Edit a large file by chunking

As a model, I change part of a large file without heredocs or in-file
markers: split the file at blank lines into `chunks/NNNNNN` files
(blank lines attach to the start of the chunk that follows them),
prove the split is lossless, overwrite one chunk with a write request
(`# write file: chunks/NNNNNN`), then join the chunks back and remove
the chunk folder. `SYSTEM_PROMPT` teaches this as a contract (a split
proven lossless with cmp, joined back with cat) without prescribing a
program; the awk splitter in this story is one valid way a model
might do it.

## Acceptance

- `cat chunks/*` reproduces the original file before any edit
  (`cmp` round-trip check passes)
- Overwriting one chunk and joining yields the expected full file,
  including the blank-line separators
- The chunk folder is removed after the join
- The run exits 0 after the `# task complete` reply
- No real network use: a fake `curl` on `PATH` serves canned
  chat-completions JSON replies
