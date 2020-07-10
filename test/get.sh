#!/bin/sh

set -e

source $(dirname $0)/helpers.sh

it_can_get_from_url() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  test_get $dest uri $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref
}

it_can_get_from_url_at_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)

  local dest=$TMPDIR/destination

  test_get $dest uri $repo ref $ref1 | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  test_get $dest uri $repo ref $ref2 | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_can_get_from_url_from_a_multibranch_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit $repo)
  local ref2=$(make_commit $repo)
  local ref3=$(make_commit_to_branch $repo branch-a)
  local ref4=$(make_commit_to_file_on_branch $repo some-other-file branch-b)
  local ref5=$(make_commit_to_file_on_branch $repo yet-other-file branch-b)
  local ref6=$(make_commit $repo)

  local dest=$TMPDIR/destination

  test_get $dest uri $repo ref "$ref3:branch-a $ref2:master" | jq -e "
    .version == {ref: $(echo "$ref3:branch-a $ref2:master" | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref3
  test "$(git -C $dest rev-parse branch-a)" = $ref3

  rm -rf $dest

  test_get $dest uri $repo ref "$ref5:branch-b $ref3:branch-a $ref2:master" | jq -e "
    .version == {ref: $(echo "$ref5:branch-b $ref3:branch-a $ref2:master" | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref5
  test "$(git -C $dest rev-parse branch-b)" = $ref5

  rm -rf $dest

  test_get $dest uri $repo ref "$ref6:master $ref5:branch-b $ref3:branch-a" | jq -e "
    .version == {ref: $(echo "$ref6:master $ref5:branch-b $ref3:branch-a" | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref6
  test "$(git -C $dest rev-parse master)" = $ref6
}

it_can_get_from_url_at_branch() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-b)

  local dest=$TMPDIR/destination

  test_get $dest uri $repo branch "branch-a" | jq -e "
    .version == {ref: $(echo $ref1 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  test_get $dest uri $repo branch "branch-b" | jq -e "
    .version == {ref: $(echo $ref2 | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2
}

it_can_get_from_url_only_single_branch() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  test_get $dest uri $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  ! git -C $dest rev-parse origin/bogus
}

it_can_get_multiple_branches_using_fetch() {
  local repo=$(init_repo)
  local ref=$(make_commit $repo)
  local dest=$TMPDIR/destination

  test_get $dest uri $repo fetch "bogus master" | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  git -C $dest rev-parse origin/bogus
}

it_honors_the_depth_flag() {
  local repo=$(init_repo)
  local firstCommitRef=$(make_commit $repo)

  make_commit $repo

  local lastCommitRef=$(make_commit $repo)

  local dest=$TMPDIR/destination

  test_get uri "file://"$repo depth 1 $dest |  jq -e "
    .version == {ref: $(echo $lastCommitRef | jq -R .)}
  "

  test "$(git -C $dest rev-parse HEAD)" = $lastCommitRef
  test "$(git -C $dest rev-list --all --count)" = 1
}

it_honors_the_depth_flag_for_submodules() {
  local repo_with_submodule_info=$(init_repo_with_submodule)
  local project_folder=$(echo $repo_with_submodule_info | cut -d "," -f1)
  local submodule_folder=$(echo $repo_with_submodule_info | cut -d "," -f2)
  local submodule_name=$(basename $submodule_folder)
  local project_last_commit_id=$(git -C $project_folder rev-parse HEAD)

  local dest_all=$TMPDIR/destination_all
  local dest_one=$TMPDIR/destination_one

  test_get $dest_all \
    uri "file://"$project_folder \
    depth 1 \
    submodules all \
  |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_all/$submodule_name rev-list --all --count)" = 1

  test_get $dest_one \
    uri "file://"$project_folder \
    depth 1 \
    submodules "$submodule_name" \
  |  jq -e "
    .version == {ref: $(echo $project_last_commit_id | jq -R .)}
  "

  test "$(git -C $project_folder rev-parse HEAD)" = $project_last_commit_id
  test "$(git -C $dest_one/$submodule_name rev-list --all --count)" = 1
}

it_can_get_from_url_at_multibranch_ref() {
  local repo=$(init_repo)
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-b)

  local dest=$TMPDIR/destination

  test_get $dest uri $repo ref "$ref1:branch-a" | jq -e "
    .version == {ref: $(echo "$ref1:branch-a" | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  test_get $dest uri $repo ref "$ref2:branch-b $ref1:branch-a" | jq -e "
    .version == {ref: $(echo "$ref2:branch-b $ref1:branch-a" | jq -R .)}
  "

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2

}

it_can_get_from_url_at_multibranch_ref_with_redis() {

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
  local ref1=$(make_commit_to_branch $repo branch-a)
  local ref2=$(make_commit_to_branch $repo branch-b)

  local dest=$TMPDIR/destination

  test_get $dest uri $repo ref "$ref1:branch-a" redis "testing" | jq -e "
    .version == {ref: $(echo "$ref1:branch-a" | jq -R .)}
  "

  test_ref_fetched "testing" $ref2:branch-a

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref1

  rm -rf $dest

  test_get $dest uri $repo ref "$ref2:branch-b" redis "testing" | jq -e "
    .version == {ref: $(echo "$ref2:branch-b" | jq -R .)}
  "

  test_ref_fetched "testing" $ref2:branch-b

  test -e $dest/some-file
  test "$(git -C $dest rev-parse HEAD)" = $ref2

}

it_can_get_git_lfs_file_as_file() {
  local repo=$(init_repo)
  local lfs_config_file_contents="*.xyz filter=lfs diff=lfs merge=lfs -text"
  make_commit_to_file_with_contents $repo .gitattributes "add git lfs config" "$lfs_config_file_contents"
  local ref=$(make_commit_to_file $repo example-git-lfs-file.xyz)
  local dest=$TMPDIR/destination

  test_get $dest uri $repo | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/example-git-lfs-file.xyz
  test -n "$(cd $dest && git-lfs ls-files)"

  # We expect this to fail as the file is a blob not a pointer. The 'or' clause
  # ensures we exit with 0 if the command fails (which is the desired outcome).
  git lfs pointer --check --file $dest/example-git-lfs-file.xyz || exit 0
}

it_can_get_git_lfs_file_as_pointer_when_git_lfs_disabled() {
  local repo=$(init_repo)
  local lfs_config_file_contents="*.xyz filter=lfs diff=lfs merge=lfs -text"
  make_commit_to_file_with_contents $repo .gitattributes "add git lfs config" "$lfs_config_file_contents"
  local ref=$(make_commit_to_file $repo example-git-lfs-file.xyz)
  local dest=$TMPDIR/destination

  test_get $dest uri $repo disable_git_lfs "true" | jq -e "
    .version == {ref: $(echo $ref | jq -R .)}
  "

  test -e $dest/example-git-lfs-file.xyz

  # In this case, since `disable_git_lfs` is 'true', we expect this pointer
  # check to return 0
  git lfs pointer --check --file $dest/example-git-lfs-file.xyz
}

run it_can_get_from_url
run it_can_get_from_url_at_ref
run it_can_get_from_url_from_a_multibranch_ref
run it_can_get_from_url_at_branch
run it_can_get_from_url_only_single_branch
run it_can_get_multiple_branches_using_fetch
run it_honors_the_depth_flag
run it_honors_the_depth_flag_for_submodules
run it_can_get_from_url_at_multibranch_ref
run it_can_get_from_url_at_multibranch_ref_with_redis
run it_can_get_git_lfs_file_as_file
run it_can_get_git_lfs_file_as_pointer_when_git_lfs_disabled
