#!/bin/bash

set -e

source $(dirname $0)/helpers.sh

# --- DEFINE TESTS ---

it_can_perform_initial_check() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)

  if [ "$ref1" \< "$ref2" ] ; then
    first_branch="master"
    ref=$ref1
  else
    first_branch="bogus"
    ref=$ref2
  fi

  test_check uri $repo branches '.*' | jq -e "
    . == [{ref: $(echo "$ref:$first_branch" | jq -R .)}]
  "
}

it_can_perform_initial_check_with_branch_filter() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)

  if [ "$ref1" \> "$ref2" ] ; then
    test_branch="master"
    ref=$ref1
  else
    test_branch="bogus"
    ref=$ref2
  fi

  test_check uri $repo branches $test_branch | jq -e "
    . == [{ref: $(echo "$ref:$test_branch" | jq -R .)}]
  "
}

it_can_perform_initial_check_with_exclusion_branch_filter() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)

  if [ "$ref1" \> "$ref2" ] ; then
    test_branch="master"
    ignore_branch="bogus"
    ref=$ref1
  else
    test_branch="bogus"
    ignore_branch="master"
    ref=$ref2
  fi

  test_check uri $repo branches '.*' ignore_branches $ignore_branch | jq -e "
    . == [{ref: $(echo "$ref:$test_branch" | jq -R .)}]
  "
}

it_can_handle_no_changes () {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)

  test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus" | jq -e "
    . == []
  "
}

it_can_find_the_changed_branch () {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo bogus)


  test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus" | jq -e "
    . == [{ref: $(echo "${ref3}:bogus $ref1:master" | jq -R .)}]
  "
}

it_can_find_a_new_branch () {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo another_branch)

  test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus" | jq -e "
    . == [{ref: $(echo "${ref3}:another_branch $ref1:master $ref2:bogus" | jq -R .)}]
  "

  remove_branch_from_repo $repo "another_branch" 

}

it_can_find_successive_branches_with_multiple_commits() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo another)
  local ref4=$(make_commit_to_branch $repo another "second to another branch")
  local ref5=$(make_commit_to_branch $repo master "second to master branch")
  local ref6=$(make_commit_to_branch $repo master "third to master branch")
  local ref7=$(make_commit_to_branch $repo another "third to another branch")
  local ref8=$(make_commit_to_branch $repo another "forth to another branch")

  echo "ref1:master  $ref1"
  echo "ref2:bogus   $ref2"
  echo "ref3:another $ref3"
  echo "ref4:another $ref4"
  echo "ref5:master  $ref5"
  echo "ref6:master  $ref6"
  echo "ref7:another $ref7"
  echo "ref8:another $ref8"

  if [ "$ref6" \< "$ref8" ] ; then
    test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" | jq -e "
      . == [
        {ref: $(echo "$ref5:master $ref2:bogus $ref3:another" | jq -R .)},
        {ref: $(echo "$ref6:master $ref2:bogus $ref3:another" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref6:master $ref2:bogus $ref3:another" | jq -e "
      . == [
        {ref: $(echo "$ref4:another $ref6:master $ref2:bogus" | jq -R .)},
        {ref: $(echo "$ref7:another $ref6:master $ref2:bogus" | jq -R .)},
        {ref: $(echo "$ref8:another $ref6:master $ref2:bogus" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref8:another $ref6:master $ref2:bogus" | jq -e "
      . == []
    "
  else
    test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" | jq -e "
      . == [
        {ref: $(echo "$ref4:another $ref1:master $ref2:bogus" | jq -R .)},
        {ref: $(echo "$ref7:another $ref1:master $ref2:bogus" | jq -R .)},
        {ref: $(echo "$ref8:another $ref1:master $ref2:bogus" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref8:another $ref1:master $ref2:bogus" | jq -e "
      . == [
        {ref: $(echo "$ref5:master $ref8:another $ref2:bogus" | jq -R .)},
        {ref: $(echo "$ref6:master $ref8:another $ref2:bogus" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref6:master $ref8:another $ref2:bogus" | jq -e "
      . == []
    "
  fi
}

it_ignores_branches_with_only_skip_commits () {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo another)

  local ref4=$(make_commit_to_be_skipped_on_branch $repo bogus "Should be skipped") 
  local ref5=$(make_commit_to_be_skipped_on_branch $repo another "Should also be skipped") 

  test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" | jq -e "
    . == []
  "

  remove_branch_from_repo $repo "another" 

}

it_can_find_branches_that_has_multiple_commits_with_latest_being_skipped () {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo another)
  local ref4=$(make_commit_to_be_skipped_on_branch $repo bogus "Should be skipped")
  local ref5=$(make_commit_to_branch $repo bogus "Not skipped") 
  local ref6=$(make_commit_to_be_skipped_on_branch $repo bogus "Should be skipped")

  test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" | jq -e "
    . == [{ref: $(echo "${ref5}:bogus $ref1:master $ref3:another" | jq -R .)}]
  "

  remove_branch_from_repo $repo "another" 

}

it_can_find_successive_branches_with_multiple_commits_with_redis() {

  set +u
  if [ "$ENABLE_REDIS_TESTS" != "TRUE" ] ; then
    echo "Skipping Redis tests because \$ENABLE_REDIS_TESTS not set to 'TRUE'"
    return 0
  elif [ "$(redis-cli ping)" != "PONG" ] ; then
    echo "Skipping Redis tests because redis not installed or not reachable"
    return 0
  fi
  set -u

  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo master)
  local ref2=$(make_commit_to_branch $repo bogus)
  local ref3=$(make_commit_to_branch $repo another)
  local ref4=$(make_commit_to_branch $repo another "second to another branch")
  local ref5=$(make_commit_to_branch $repo master "second to master branch")
  local ref6=$(make_commit_to_branch $repo master "third to master branch")
  local ref7=$(make_commit_to_branch $repo another "third to another branch")
  local ref8=$(make_commit_to_branch $repo another "forth to another branch")

  echo "ref1:master  $ref1"
  echo "ref2:bogus   $ref2"
  echo "ref3:another $ref3"
  echo "ref4:another $ref4"
  echo "ref5:master  $ref5"
  echo "ref6:master  $ref6"
  echo "ref7:another $ref7"
  echo "ref8:another $ref8"

  if [ "$ref6" \< "$ref8" ] ; then

    echo "master is least commit"
    test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" redis "testing" | jq -e "
      . == [
        {ref: $(echo "$ref5:master" | jq -R .)},
        {ref: $(echo "$ref6:master" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref6:master" redis "testing" | jq -e "
      . == [
        {ref: $(echo "$ref4:another" | jq -R .)},
        {ref: $(echo "$ref7:another" | jq -R .)},
        {ref: $(echo "$ref8:another" | jq -R .)}
      ]
    "

    test_check uri $repo branches '.*' from "$ref8:another" redis "testing" | jq -e "
      . == []
    "

    test_redis "testing" "$ref5:master" "$ref2:bogus $ref3:another"
    test_redis "testing" "$ref6:master" "$ref2:bogus $ref3:another"
    test_redis "testing" "$ref4:another" "$ref6:master $ref2:bogus"
    test_redis "testing" "$ref7:another" "$ref6:master $ref2:bogus"
    test_redis "testing" "$ref8:another" "$ref6:master $ref2:bogus"
    
  else
    echo "another is least commit"
    test_check uri $repo branches '.*' from "$ref1:master $ref2:bogus $ref3:another" redis "different-key" | jq -e "
      . == [
        {ref: $(echo "$ref4:another" | jq -R .)},
        {ref: $(echo "$ref7:another" | jq -R .)},
        {ref: $(echo "$ref8:another" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref8:another" redis "different-key"| jq -e "
      . == [
        {ref: $(echo "$ref5:master" | jq -R .)},
        {ref: $(echo "$ref6:master" | jq -R .)}
      ]
    "
    test_check uri $repo branches '.*' from "$ref6:master" redis "different-key" | jq -e "
      . == []
    "

    test_redis "different-key" "$ref5:master" "$ref8:another $ref2:bogus"
    test_redis "different-key" "$ref6:master" "$ref8:another $ref2:bogus"
    test_redis "different-key" "$ref4:another" "$ref1:master $ref2:bogus"
    test_redis "different-key" "$ref7:another" "$ref1:master $ref2:bogus"
    test_redis "different-key" "$ref8:another" "$ref1:master $ref2:bogus"
  fi
}

# --- RUN TESTS ---

run it_can_perform_initial_check
run it_can_perform_initial_check_with_branch_filter
run it_can_perform_initial_check_with_exclusion_branch_filter
run it_can_handle_no_changes
run it_can_find_the_changed_branch
run it_can_find_a_new_branch
run it_can_find_successive_branches_with_multiple_commits
run it_ignores_branches_with_only_skip_commits
run it_can_find_branches_that_has_multiple_commits_with_latest_being_skipped
run it_can_find_successive_branches_with_multiple_commits_with_redis
