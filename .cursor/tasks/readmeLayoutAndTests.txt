readmeLayoutAndTests — README tree and how to run tests

Why:
README layout omits tests/ and oldTests/. The supported entry point
is not listed.

Do:
Add tests/ (and that oldTests/ is archive) to the layout tree. Add:

  sh tests/runTests.sh

Keep product surface small; do not document every story folder.

May overlap readmeLocalModelRecipe.txt; one README edit can do both.
