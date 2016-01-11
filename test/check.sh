#!/bin/sh

set -e

source $(dirname $0)/helpers.sh

it_can_check_from_head() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  test_check uri $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
}

it_can_check_from_head_only_fetching_single_branch() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local cachedir="$TMPDIR/git-resource-repo-cache"

  test_check uri $repo | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "

  ! git -C $cachedir rev-parse origin/bogus
}

it_can_check_if_key_is_passwordless() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local key=$TMPDIR/key-without-passphrase
  ssh-keygen -f $key -N ""

  local failed_output=$TMPDIR/failed-output
  test_check uri $repo key $key 2>$failed_output | jq -e "
    . == [{ref: $(echo $ref | jq -R .)}]
  "
}

it_fails_if_key_has_password() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)

  local key=$TMPDIR/key-with-passphrase
  ssh-keygen -f $key -N some-passphrase

  local failed_output=$TMPDIR/failed-output
  if test_check uri $repo key $key 2>$failed_output; then
    echo "checking should have failed"
    return 1
  fi

  grep "Private keys with passphrases are not supported." $failed_output
}

it_can_check_from_a_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit $repo)

  test_check uri $repo from $ref1 | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_can_check_from_a_bogus_sha() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  test_check uri $repo from "bogus-ref" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_skips_ignored_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo file-c)

  test_check uri $repo ignore_paths "file-c" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "

  test_check uri $repo from $ref1 ignore_paths "file-c" | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  test_check uri $repo ignore_paths "file-c" | jq -e "
    . == [{ref: $(echo $ref4 | jq -R .)}]
  "

  test_check uri $repo from $ref1 ignore_paths "file-c" | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)},
      {ref: $(echo $ref4 | jq -R .)}
    ]
  "
}

it_checks_given_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo file-c)

  test_check uri $repo paths "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  test_check uri $repo from $ref1 paths "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  local ref4=$(make_commit_to_file $repo file-b)

  test_check uri $repo paths "file-c" | jq -e "
    . == [{ref: $(echo $ref3 | jq -R .)}]
  "

  local ref5=$(make_commit_to_file $repo file-c)

  test_check uri $repo from $ref1 paths "file-c" | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)},
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
}

it_checks_given_ignored_paths() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_file $repo file-a)
  local ref2=$(make_commit_to_file $repo file-b)
  local ref3=$(make_commit_to_file $repo some-file)

  test_check uri $repo paths 'file-*' ignore_paths 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  test_check uri $repo from $ref1 paths 'file-*' ignore_paths 'file-b' | jq -e "
    . == []
  "

  local ref4=$(make_commit_to_file $repo file-b)

  test_check uri $repo paths 'file-*' ignore_paths 'file-b' | jq -e "
    . == [{ref: $(echo $ref1 | jq -R .)}]
  "

  local ref5=$(make_commit_to_file $repo file-a)

  test_check uri $repo from $ref1 paths 'file-*' ignore_paths 'file-b' | jq -e "
    . == [{ref: $(echo $ref5 | jq -R .)}]
  "

  local ref6=$(make_commit_to_file $repo file-c)

  local ref7=$(make_commit_to_file $repo some-file)

  test_check uri $repo from $ref1 paths 'file-*' ignore_paths 'file-b' | jq -e "
    . == [
      {ref: $(echo $ref5 | jq -R .)},
      {ref: $(echo $ref6 | jq -R .)}
    ]
  "

  test_check uri $repo from $ref1 paths 'file-*' ignore_paths 'file-b file-c' | jq -e "
    . == [
      {ref: $(echo $ref5 | jq -R .)}
    ]
  "
}

it_can_check_when_not_ff() {
  local repo=$(init_repo)
  local other_repo=$(init_repo)

  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  local ref3=$(make_commit $other_repo)

  test_check uri $other_repo

  cd "$TMPDIR/git-resource-repo-cache"

  # do this so we get into a situation that git can't resolve by rebasing
  git config branch.autosetuprebase never

  # set my remote to be the other git repo
  git remote remove origin
  git remote add origin $repo/.git

  # fetch so we have master available to track
  git fetch

  # setup tracking for my branch
  git branch -u origin/master HEAD

  test_check uri $other_repo | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

it_skips_marked_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit $repo)

  test_check uri $repo from $ref1 | jq -e "
    . == [
      {ref: $(echo $ref3 | jq -R .)}
    ]
  "
}

it_skips_marked_commits_with_no_version() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit_to_be_skipped $repo)
  local ref3=$(make_commit_to_be_skipped $repo)

  test_check uri $repo | jq -e "
    . == [
      {ref: $(echo $ref1 | jq -R .)}
    ]
  "
}

it_can_check_empty_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_empty_commit $repo)

  test_check uri $repo from $ref1 | jq -e "
    . == [
      {ref: $(echo $ref2 | jq -R .)}
    ]
  "
}

it_can_check_from_head_with_empty_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_empty_commit $repo)

  test_check uri $repo | jq -e "
    . == [{ref: $(echo $ref2 | jq -R .)}]
  "
}

run it_can_check_from_head
run it_can_check_from_a_ref
run it_can_check_from_a_bogus_sha
run it_skips_ignored_paths
run it_checks_given_paths
run it_checks_given_ignored_paths
#run it_can_check_when_not_ff
run it_skips_marked_commits
run it_skips_marked_commits_with_no_version
run it_fails_if_key_has_password
run it_can_check_if_key_is_passwordless
run it_can_check_empty_commits
run it_can_check_from_head_only_fetching_single_branch
