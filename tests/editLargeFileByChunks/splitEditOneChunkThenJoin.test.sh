#!/bin/sh
# Model splits a file into chunks at blank lines, proves the split is
# lossless, overwrites one chunk with a write request, joins back.
# The prompt does not teach this; the awk splitter is one way a model
# might do it.

set -u
. "$TEST_UTILS_FILE"

setup_fake_model
setup_work_folder

cat >"$WORK_FOLDER/big.txt" <<'SEED' || fail "cannot seed big.txt"
alpha one
alpha two

beta one
beta two

gamma one
SEED

add_model_reply 1 <<'REPLY'
# Split big.txt into chunk files and prove the split is lossless.
mkdir chunks
awk '$0 == "" { blanks = blanks + 1; next }
    { if (file == "" || blanks > 0) { close(file)
        chunk = chunk + 10; file = sprintf("chunks/%06d", chunk) }
      while (blanks > 0) { print "" > file; blanks = blanks - 1 }
      print > file }
    END { while (blanks > 0) { print "" > file; blanks = blanks - 1 } }
' big.txt
cat chunks/* > check && cmp big.txt check && rm check
grep -n . chunks/*
REPLY

add_model_reply 2 <<'REPLY'
# write file: chunks/000020

beta one rewritten
beta two rewritten
beta three added
REPLY

add_model_reply 3 <<'REPLY'
# Join the chunks back onto big.txt and clean up.
cat chunks/* > big.txt.new && mv big.txt.new big.txt && rm -r chunks
REPLY

add_model_reply 4 <<'REPLY'
# task complete
REPLY

cat >"$TEST_TEMP_FOLDER/expected.txt" <<'EXPECTED'
alpha one
alpha two

beta one rewritten
beta two rewritten
beta three added

gamma one
EXPECTED

run_ssa_task change the beta section of big.txt
expect_exit 0
expect_stderr_has 'done: task complete after 4 model prompts'
expect_stdout_has 'chunks/000020'
expect_file_equals "$WORK_FOLDER/big.txt" "$TEST_TEMP_FOLDER/expected.txt"
expect_no_file "$WORK_FOLDER/chunks"
expect_no_file "$WORK_FOLDER/check"
