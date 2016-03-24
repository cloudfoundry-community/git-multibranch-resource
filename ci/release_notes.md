# Initial Release

This is the initial release of git-multibranch-resource, a resource for
testing multiple branches of a git repository in a single pipeline.

## Functionality

By using `branches` instead of `branch` in the source configuration, you specify a
regular expression patter of the branches you want to target.  Optionally, if
you specify `ignore_branches`, you can set a similar pattern for branches that
you want to ommit (takes precidence over `branches`)

## Everythings better with redis

If you use the optional redis extension, you will reap the following benefits:
* The ref space will not be cluttered with all the latests refs for all other
  branches.
  * Normally  the first ref listed is the ref for that ci run, will all the
    other refs used to track what branch refs have already been tested.  With
    redis available, this extra information is stored in redis.
* No branch update will be untested.
  * If you have enough workers, this isn't usually a problem.  But if it is,
    the check will be prevented from reporting another branch's latest ref
    until a worker is available.  This prevents branches from being skipped by
    a later reported ref of another branch.

## ToDo

Features of future releases includes:
* The wait until worker available feature should continue checking if there's
  an update for the pending branch and report updates for that branch, but no
  others.

