#!/bin/sh
# Sets Sigil up on Ubuntu: installs git if it is missing, clones the repository into ./sigil,
# every branch a worktree beside the bare clone in ./sigil/.git, and runs the checkout's
# tools/environment_setup.sh, which installs the other prerequisites and sets the checkout up.
# Safe to run again: it skips what is done.
#
# In a terminal, in the folder that should hold sigil/:
#   sh -c "$(wget -qO- https://raw.githubusercontent.com/mdally/sigil-bootstrap/main/bootstrap.sh)"
# as sh -c, rather than through a pipe, so that sudo and setup can ask their questions.
#
# The repository is private, and this clones it over SSH, with the SSH key added to your GitHub
# account.
set -eu
# Where to clone from; the environment tests pass a local copy.
repository="${1:-git@github.com:mdally/sigil.git}"

step() { printf 'bootstrap: %s\n' "$*"; }

if ! command -v git >/dev/null; then
  step 'installing git from Ubuntu'"'"'s archive'
  # Without questions: those of a package's own setup take their defaults.
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git
fi

if [ ! -d sigil/.git ]; then
  step "cloning $repository into sigil/"
  git clone --bare "$repository" sigil/.git
  # A bare clone has no remote-tracking branches, which worktrees start from.
  git -C sigil/.git config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
  git -C sigil/.git fetch origin
  git -C sigil/.git remote set-head origin --auto
fi
if [ ! -e sigil/main/.git ]; then
  step 'checking out main into sigil/main'
  git -C sigil/.git worktree add "$PWD/sigil/main" main
  git -C sigil/main branch --set-upstream-to=origin/main main
fi

step "running the checkout's tools/environment_setup.sh"
exec sh sigil/main/tools/environment_setup.sh
