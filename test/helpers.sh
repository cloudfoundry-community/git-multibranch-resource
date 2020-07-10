#!/bin/bash

set -e -u

set -o pipefail


resource_dir=/opt/resource

run() {
  export TMPDIR=$(mktemp -d ${TMPDIR_ROOT}/git-tests.XXXXXX)

  echo -e 'running \e[33m'"$@"'\e[0m...'
  eval "$@" 2>&1 | sed -e 's/^/  /g'
  echo -e '\e[32m'"$@ passed!"'\e[0m'
  echo ""
  echo ""
}


init_repo() {
  (
    set -e

    cd $(mktemp -d $TMPDIR/repo.XXXXXX)

    git init -q

    # start with an initial commit
    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q --allow-empty -m "init"

    # create some bogus branch
    git checkout -b bogus

    git \
      -c user.name='test' \
      -c user.email='test@example.com' \
      commit -q --allow-empty -m "commit on other branch"

    # back to master
    git checkout master

    # print resulting repo
    pwd
  )
}

remove_branch_from_repo () {
  local repo=$1
  local branch=$2
  git -C $repo checkout ${3:-master}
  git -C $repo branch -D $branch
}

init_repo_with_submodule() {
  local submodule=$(init_repo)
  make_commit $submodule >/dev/null
  make_commit $submodule >/dev/null

  local project=$(init_repo)
  git -C $project submodule add "file://$submodule" >/dev/null
  git -C $project commit -m "Adding Submodule" >/dev/null
  echo $project,$submodule
}

make_commit_to_file_on_branch() {
  local repo=$1
  local file=$2
  local branch=$3
  local msg=${4-}
  local file_contents=${5-x}

  # ensure branch exists
  if ! git -C $repo rev-parse --verify $branch >/dev/null 2>&1; then
    git -C $repo branch $branch master
  fi

  # switch to branch
  git -C $repo checkout -q $branch

  # modify file and commit
  echo $file_contents >> $repo/$file
  git -C $repo add $file
  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q -m "commit $(wc -l $repo/$file) $msg"

  # output resulting sha
  git -C $repo rev-parse HEAD
}

make_commit_to_file() {
  make_commit_to_file_on_branch $1 $2 master "${3-}"
}

make_commit_to_file_with_contents() {
  make_commit_to_file_on_branch $1 $2 master "${3-}" "${4}"
}

make_commit_to_branch() {
  make_commit_to_file_on_branch $1 some-file $2
}

make_commit() {
  make_commit_to_file $1 some-file
}

make_commit_to_be_skipped() {
  make_commit_to_file $1 some-file "[ci skip]"
}

make_commit_to_be_skipped_on_branch() {
  make_commit_to_file_on_branch $1 some-file $2 "[ci skip]$3"
}

make_empty_commit() {
  local repo=$1
  local msg=${2-}

  git -C $repo \
    -c user.name='test' \
    -c user.email='test@example.com' \
    commit -q --allow-empty -m "commit $msg"

  # output resulting sha
  git -C $repo rev-parse HEAD
}

test_check() {

  local addition=""
  local arg=""
  local json="{}"

  while [ $# -gt 0 ] ; do

    arg=$1 ; shift
    addition=""
    case $arg in
      "uri" )
        addition="$(jq -n "{
          source: {
            uri: $(echo $1 | jq -R .)
          }
        }")"
        shift;;

      "key" )
        addition="$(jq -n "{
          source: {
            private_key: $(cat $1 | jq -s -R .)
          }
        }")"
        shift;;

      "ignore_paths" )
        addition="$(jq -n "{
          source: {
            ignore_paths: $(echo $1 | jq -R '. | split(" ")')
          }
        }")"
        shift;;

      "paths" )
        addition="$(jq -n "{
          source: {
            paths: $(echo $1 | jq -R '. | split(" ")')
          }
        }")"
        shift;;

      "from" )
        addition="$(jq -n "{
          version: {
            ref: $(echo $1 | jq -R .)
          }
        }")"
        shift;;

      "branches" )
        addition="$(jq -n "{
          source: {
            branches: $(echo "$1" | jq -R '.')
          }
        }")"
        shift;;

      "ignore_branches" )
        addition="$(jq -n "{
          source: {
            ignore_branches: $(echo "$1" | jq -R '.')
          }
        }")"
        shift;;

      "redis" )
        addition="$(jq -n "{
          source: {
            redis: {
              host: $(echo "localhost" | jq -R '.'),
              prefix: $(echo "$1" | jq -R '.')
            }
          }
        }")"
        shift;;

      * )
        echo -e '\e[31m'"Unknown argument '$arg'"'\e[0m' >&2
        exit 1;;

    esac

    if [ "$addition" != "" ] ; then
      json="$(echo $json $addition | jq -s '.[0] * .[1]')"
    fi

  done


  echo $json | ${resource_dir}/check | tee /dev/stderr
}

test_get() {
  local addition=""
  local arg=""
  local json="{}"
  local destination

  while [ $# -gt 0 ] ; do

    arg=$1 ; shift
    addition=""
    case $arg in
      "uri" )
        addition="$(jq -n "{
          source: {
            uri: $(echo $1 | jq -R .)
          }
        }")"
        shift;;

      "depth" )
        addition="$(jq -n "{
          params: {
            depth: $(echo $1 | jq -R .)
          }
        }")"
        shift;;

      "submodules" )
        local submodules='"all"'
        if [ "$1" != "all" ] ; then
          submodules="[$(echo $1 | jq -R .)]"
        fi
        addition="$(jq -n "{
          params: {
            submodules: $submodules
          }
        }")"
        shift;;

      "ref" )
        addition="$(jq -n "{
          version: {
            ref: $(echo $1 | jq -R .)
          }
        }")"
        shift;;

      "branch" )
        addition="$(jq -n "{
          source: {
            branch: $(echo "$1" | jq -R '.')
          }
        }")"
        shift;;

      "fetch" )
        addition="$(jq -n "{
          params: {
            fetch: $(echo $1 | jq -R '. | split(" ")')
          }
        }")"
        shift;;

      "redis" )
        addition="$(jq -n "{
          source: {
            redis: {
              host: $(echo "localhost" | jq -R '.'),
              prefix: $(echo "$1" | jq -R '.')
            }
          }
        }")"
        shift;;

      "disable_git_lfs" )
        addition="$(jq -n "{
          params: {
            disable_git_lfs: $(echo "$1" | jq -R .)
          }
        }")"
        shift;;

      * )
        if [ -z ${destination+is_set} ] ; then
          destination=$arg
        else
          echo -e '\e[31m'"Unknown argument '$arg'"'\e[0m' >&2
          exit 1
        fi
        ;;

    esac

    if [ "$addition" != "" ] ; then
      json="$(echo $json $addition | jq -s '.[0] * .[1]')"
    fi

  done

  if [ -z ${destination+is_set} ] ; then
    echo -e '\e[31m'"ERROR: destination not specified for test_get"'\e[0m' >&2
    exit 1
  fi

  echo $json | ${resource_dir}/in $destination | tee /dev/stderr
}

test_redis() {
  result="$(redis-cli get "${1:+${1}:}ancestry:$2")"
  if [ "$result" != "$3" ] ; then
    echo "Expected redis-cli get \"${1:+${1}:}$2\" to return:"
    echo "$3"
    echo ""
    echo "Instead, it returned:"
    echo "$result"
    echo ""
    return 1
  fi
}

set_ref_fetched() {
  redis-cli set "${1:+${1}:}fetched:$2" "${3:-true}"
}

test_ref_fetched() {
  expected="${3:-true}"
  result="$(redis-cli --raw get "${1:+${1}:}fetched:$2")"
  if [ "$result" != "${expected}" ] ; then
    echo "Expected redis-cli get \"${1:+${1}:}fetched:$2\" to return:"
    echo "${expected}"
    echo ""
    echo "Instead, it returned:"
    echo "$result"
    echo ""
    return 1
  fi
}

test_put() {
  echo ''
}

put_uri() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_only_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      only_tag: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      repository: $(echo $3 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_tag_and_prefix() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      tag_prefix: $(echo $4 | jq -R .),
      repository: $(echo $5 | jq -R .)
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase_with_tag() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      repository: $(echo $4 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_rebase_with_tag_and_prefix() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branch: \"master\"
    },
    params: {
      tag: $(echo $3 | jq -R .),
      tag_prefix: $(echo $4 | jq -R .),
      repository: $(echo $5 | jq -R .),
      rebase: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}

put_uri_with_multibranch() {
  jq -n "{
    source: {
      uri: $(echo $1 | jq -R .),
      branches: $(echo $4 | jq -R .)
    },
    params: {
      repository: $(echo $3 | jq -R .),
      multibranch: true
    }
  }" | ${resource_dir}/out "$2" | tee /dev/stderr
}
