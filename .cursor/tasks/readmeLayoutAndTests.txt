readmeLayoutAndTests — README tree and how to run tests

Why:
README layout omits tests/. The supported entry point is not listed.

Do:
Add tests/ to the layout tree. Do not add oldTests/; that folder is
slated for removal (removeOldTests.txt). Add:

  sh tests/runTests.sh

Keep product surface small; do not document every story folder.

May overlap readmeLocalModelRecipe.txt; one README edit can do both.
