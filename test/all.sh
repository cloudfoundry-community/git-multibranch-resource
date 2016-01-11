#!/bin/sh

set -e

export TMPDIR_ROOT=$(mktemp -d /tmp/git-tests.XXXXXX)

on_exit() {
  exitcode=$?
  if [ $exitcode != 0 ] ; then
    echo -e '\e[41;33;1m'"Failure encountered!"'\e[0m'
    echo ""
    echo "Delete $TMPDIR_ROOT when done inspecting the failure"
    echo ""
  else
    rm -rf $TMPDIR_ROOT
  fi

}

trap on_exit EXIT

$(dirname $0)/check.sh
$(dirname $0)/check_multi.sh
$(dirname $0)/get.sh
$(dirname $0)/put.sh

echo -e '\e[32;1m'"All tests passed!"'\e[0m'

